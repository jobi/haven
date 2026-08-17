import Foundation

public struct ServerConfig: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var url: URL
    public var internalURL: URL?
    public var lastConnected: Date?
    
    public init(
        id: String = UUID().uuidString,
        name: String = "Home Assistant",
        url: URL,
        internalURL: URL? = nil,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.internalURL = internalURL
        self.lastConnected = lastConnected
    }
    
    /// Normalizes URL string input by removing trailing slashes and ensuring a scheme
    public static func normalizeURLString(_ input: String) -> URL? {
        var clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.lowercased().hasPrefix("http://") && !clean.lowercased().hasPrefix("https://") {
            clean = "http://" + clean
        }
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        return URL(string: clean)
    }
}

public struct AuthTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String
    public let expiresIn: Int?
    public let createdAt: Date
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: Int? = 1800,
        createdAt: Date = Date()
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.createdAt = createdAt
    }
    
    public var isExpired: Bool {
        guard let expiresIn = expiresIn else { return false }
        // Buffer of 60 seconds
        return Date().timeIntervalSince(createdAt) >= Double(expiresIn - 60)
    }
}
