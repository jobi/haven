import Foundation

public struct HARestClient: Sendable {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Tests connectivity to a Home Assistant server URL by hitting `/manifest.json`, `/`, or `/api/discovery_info`
    public func testConnection(url: URL) async throws -> Bool {
        // 1. Try hitting /manifest.json (standard in all modern HA instances)
        let manifestURL = url.appendingPathComponent("manifest.json")
        var manifestReq = URLRequest(url: manifestURL)
        manifestReq.httpMethod = "GET"
        manifestReq.timeoutInterval = 6.0
        
        if let (_, response) = try? await session.data(for: manifestReq),
           let http = response as? HTTPURLResponse,
           (200...299).contains(http.statusCode) {
            return true
        }
        
        // 2. Try hitting root /
        var rootRequest = URLRequest(url: url)
        rootRequest.httpMethod = "GET"
        rootRequest.timeoutInterval = 6.0
        
        if let (_, response) = try? await session.data(for: rootRequest),
           let http = response as? HTTPURLResponse,
           (200...399).contains(http.statusCode) {
            return true
        }
        
        // 3. Try hitting /api/discovery_info or /api/
        let discoveryURL = url.appendingPathComponent("api/discovery_info")
        var discReq = URLRequest(url: discoveryURL)
        discReq.httpMethod = "GET"
        discReq.timeoutInterval = 6.0
        
        if let (_, response) = try? await session.data(for: discReq),
           let http = response as? HTTPURLResponse,
           (200...299).contains(http.statusCode) || http.statusCode == 401 || http.statusCode == 405 {
            return true
        }
        
        return false
    }
    
    /// Exchanges an OAuth2 authorization code for access and refresh tokens
    public func exchangeAuthorizationCode(
        serverURL: URL,
        code: String,
        clientId: String
    ) async throws -> AuthTokens {
        let tokenURL = serverURL.appendingPathComponent("auth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = [
            "grant_type=authorization_code",
            "code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code)",
            "client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId)"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.tokenExchangeFailed(message: errorText)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return AuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            tokenType: tokenResponse.tokenType,
            expiresIn: tokenResponse.expiresIn
        )
    }
    
    /// Refreshes an expired access token using a refresh token
    public func refreshAccessToken(
        serverURL: URL,
        refreshToken: String,
        clientId: String
    ) async throws -> AuthTokens {
        let tokenURL = serverURL.appendingPathComponent("auth/token")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refreshToken)",
            "client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId)"
        ]
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NetworkError.tokenRefreshFailed(message: errorText)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return AuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: refreshToken, // Retain existing refresh token if not returned
            tokenType: tokenResponse.tokenType,
            expiresIn: tokenResponse.expiresIn
        )
    }
    
    // MARK: - Entity State & Service Calls (used by Widgets & AppIntents)
    
    /// Fetches the current state of a single entity via `GET /api/states/<entity_id>`
    public func fetchEntityState(
        serverURL: URL,
        token: String,
        entityId: String
    ) async throws -> HAEntityState {
        let url = serverURL.appendingPathComponent("api/states/\(entityId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw NetworkError.requestFailed(message: errorText)
        }
        
        let raw = try JSONDecoder().decode(RESTEntityState.self, from: data)
        return raw.toEntityState()
    }
    
    /// Fetches all entity states via `GET /api/states`
    public func fetchAllStates(
        serverURL: URL,
        token: String
    ) async throws -> [HAEntityState] {
        let url = serverURL.appendingPathComponent("api/states")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw NetworkError.requestFailed(message: errorText)
        }
        
        let rawList = try JSONDecoder().decode([RESTEntityState].self, from: data)
        return rawList.map { $0.toEntityState() }
    }
    
    /// Invokes a Home Assistant service via `POST /api/services/<domain>/<service>`
    public func callService(
        serverURL: URL,
        token: String,
        domain: String,
        service: String,
        entityId: String,
        serviceData: [String: AnyCodable]? = nil
    ) async throws {
        let url = serverURL.appendingPathComponent("api/services/\(domain)/\(service)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: AnyCodable] = serviceData ?? [:]
        payload["entity_id"] = AnyCodable(entityId)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw NetworkError.requestFailed(message: errorText)
        }
    }
    
    public enum NetworkError: Error, LocalizedError {
        case unreachable
        case tokenExchangeFailed(message: String)
        case tokenRefreshFailed(message: String)
        case requestFailed(message: String)
        
        public var errorDescription: String? {
            switch self {
            case .unreachable:
                return "The Home Assistant server is unreachable."
            case .tokenExchangeFailed(let msg):
                return "Failed to exchange authorization code: \(msg)"
            case .tokenRefreshFailed(let msg):
                return "Failed to refresh access token: \(msg)"
            case .requestFailed(let msg):
                return "Home Assistant request failed: \(msg)"
            }
        }
    }
}

private struct RESTEntityState: Decodable {
    let entityId: String
    let state: String
    let attributes: [String: AnyCodable]?
    let lastChanged: String?
    let lastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }
    
    func toEntityState() -> HAEntityState {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIso = ISO8601DateFormatter()
        
        func parseDate(_ str: String?) -> Date? {
            guard let str else { return nil }
            return iso.date(from: str) ?? fallbackIso.date(from: str)
        }
        
        return HAEntityState(
            entityId: entityId,
            state: state,
            attributes: attributes ?? [:],
            lastChanged: parseDate(lastChanged),
            lastUpdated: parseDate(lastUpdated)
        )
    }
}

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}
