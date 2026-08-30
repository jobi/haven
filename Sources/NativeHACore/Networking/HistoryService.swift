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
        
        // Count of samples: 48 points for 24h (every 30m), 36 for 12h (every 20m), 24 for 6h (every 15m)
        let count = min(48, max(24, hours * 2))
        let step = Double(hours * 3600) / Double(count - 1)
        let now = Date()
        
        // Deterministic hash seed from entityId
        var hash: UInt32 = 5381
        for byte in entityId.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt32(byte)
        }
        
        let phi1 = (Double(hash & 0xFF) / 255.0) * 2.0 * .pi
        let phi2 = (Double((hash >> 8) & 0xFF) / 255.0) * 2.0 * .pi
        let phi3 = (Double((hash >> 16) & 0xFF) / 255.0) * 2.0 * .pi
        
        let lowerId = entityId.lowercased()
        let isTemp = lowerId.contains("temp")
        let isHumidity = lowerId.contains("humidity")
        let isPower = lowerId.contains("power") || lowerId.contains("watt") || lowerId.contains("energy")
        let isSolar = lowerId.contains("solar")
        
        let ampScale: Double
        if isSolar {
            ampScale = 0.50
        } else if isPower {
            ampScale = 0.30
        } else if isHumidity {
            ampScale = 0.12
        } else if isTemp {
            ampScale = 0.06
        } else {
            ampScale = 0.08
        }
        
        let a1 = max(0.5, baseVal * ampScale)
        let a2 = a1 * 0.35
        let a3 = a1 * 0.15
        
        var points: [HistoryDataPoint] = []
        for i in 0..<count {
            let offset = Double(count - 1 - i) * step
            let date = now.addingTimeInterval(-offset)
            
            // deltaT <= 0 in hours relative to now (0 = now, -2.5 = 2.5 hours ago)
            let deltaT = -offset / 3600.0
            
            // Harmonic wave anchored continuously at deltaT = 0 (so wave(0) == 0 with no discontinuity)
            let w1 = a1 * (sin((2.0 * .pi * deltaT / 24.0) + phi1) - sin(phi1))
            let w2 = a2 * (sin((2.0 * .pi * deltaT / 8.0) + phi2) - sin(phi2))
            let w3 = a3 * (sin((2.0 * .pi * deltaT / 2.5) + phi3) - sin(phi3))
            
            var simulatedVal = baseVal + w1 + w2 + w3
            
            // Power / Solar can have realistic burst activity
            if isPower {
                // Occasional power spikes (e.g. appliances cycling)
                let spikeFreq = sin((2.0 * .pi * deltaT / 3.0) + phi2)
                if spikeFreq > 0.7 {
                    simulatedVal += a1 * 0.8 * (spikeFreq - 0.7)
                }
            } else if isSolar {
                simulatedVal = max(0.0, simulatedVal)
            }
            
            simulatedVal = max(0.0, simulatedVal)
            
            points.append(HistoryDataPoint(
                timestamp: date,
                value: simulatedVal,
                stateString: String(format: "%.1f", simulatedVal)
            ))
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
