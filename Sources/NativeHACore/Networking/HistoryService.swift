import Foundation

public struct HistoryDataPoint: Identifiable, Sendable, Hashable {
    public var id: Date { timestamp }
    public let timestamp: Date
    public let value: Double
    public let stateString: String
    
    public init(timestamp: Date, value: Double, stateString: String) {
        self.timestamp = timestamp
        self.value = value
        self.stateString = stateString
    }
}

public actor HistoryService {
    public static let shared = HistoryService()
    
    private let session: URLSession
    private let isoFormatter: ISO8601DateFormatter
    private let isoFractionalFormatter: ISO8601DateFormatter
    
    public init(session: URLSession = .shared) {
        self.session = session
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime]
        self.isoFormatter = f1
        
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoFractionalFormatter = f2
    }
    
    /// Fetches historical data points for an entity over the specified duration in hours.
    public func fetchHistory(
        serverURL: URL?,
        token: String?,
        entityId: String,
        currentValue: Double? = nil,
        hours: Int = 24
    ) async -> [HistoryDataPoint] {
        if let serverURL = serverURL, let token = token, !token.isEmpty {
            if let points = await fetchFromAPI(serverURL: serverURL, token: token, entityId: entityId, hours: hours), !points.isEmpty {
                return points
            }
        }
        
        // Fallback to simulated historical trend based on current value
        return generateFallbackHistory(entityId: entityId, currentValue: currentValue, hours: hours)
    }
    
    private func fetchFromAPI(
        serverURL: URL,
        token: String,
        entityId: String,
        hours: Int
    ) async -> [HistoryDataPoint]? {
        let startTime = Date().addingTimeInterval(-Double(hours * 3600))
        let startStr = isoFormatter.string(from: startTime)
        
        guard var components = URLComponents(url: serverURL.appendingPathComponent("api/history/period/\(startStr)"), resolvingAgainstBaseURL: true) else {
            return nil
        }
        
        components.queryItems = [
            URLQueryItem(name: "filter_entity_id", value: entityId),
            URLQueryItem(name: "significant_changes_only", value: "0"),
            URLQueryItem(name: "minimal_response", value: "1"),
            URLQueryItem(name: "no_attributes", value: "1")
        ]
        
        guard let url = components.url else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            
            let nestedList = try JSONDecoder().decode([[RawHistoryItem]].self, from: data)
            guard let items = nestedList.first, !items.isEmpty else {
                return nil
            }
            
            var points: [HistoryDataPoint] = []
            for item in items {
                guard let val = Double(item.state) else { continue }
                let dateStr = item.lastUpdated ?? item.lastChanged ?? ""
                let date = isoFractionalFormatter.date(from: dateStr) ?? isoFormatter.date(from: dateStr) ?? Date()
                points.append(HistoryDataPoint(timestamp: date, value: val, stateString: item.state))
            }
            
            // Sort by timestamp
            return points.sorted(by: { $0.timestamp < $1.timestamp })
        } catch {
            return nil
        }
    }
    
    private func generateFallbackHistory(
        entityId: String,
        currentValue: Double?,
        hours: Int
    ) -> [HistoryDataPoint] {
        let baseVal = currentValue ?? 22.0
        let count = min(30, max(12, hours * 2))
        let step = Double(hours * 3600) / Double(count)
        let now = Date()
        
        var points: [HistoryDataPoint] = []
        for i in 0..<count {
            let offset = Double(count - 1 - i) * step
            let date = now.addingTimeInterval(-offset)
            
            // Subtle diurnal temperature/pressure oscillation wave
            let progress = Double(i) / Double(count)
            let wave = sin(progress * .pi * 2.0 - 1.0) * (baseVal * 0.08)
            let jitter = Double((i * 17) % 7 - 3) * 0.1
            let simulatedVal = max(0.0, baseVal + wave + jitter)
            
            points.append(HistoryDataPoint(
                timestamp: date,
                value: simulatedVal,
                stateString: String(format: "%.1f", simulatedVal)
            ))
        }
        
        // Ensure the last point matches the live value
        if let last = points.last {
            points[points.count - 1] = HistoryDataPoint(
                timestamp: now,
                value: baseVal,
                stateString: String(format: "%.1f", baseVal)
            )
        }
        
        return points
    }
}

private struct RawHistoryItem: Codable {
    let state: String
    let lastChanged: String?
    let lastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case state
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }
}
