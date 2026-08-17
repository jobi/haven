import Foundation

public actor HAAuthManager {
    public static let shared = HAAuthManager()
    
    private let keychain: KeychainStorage
    private let restClient: HARestClient
    public static let defaultClientId = "https://home-assistant.io/iOS"
    
    public init(keychain: KeychainStorage = .shared, restClient: HARestClient = HARestClient()) {
        self.keychain = keychain
        self.restClient = restClient
    }
    
    /// Returns the active access token for a server, refreshing it if necessary
    public func getValidAccessToken(for server: ServerConfig) async throws -> String {
        guard let tokens = try await keychain.retrieveTokens(forServerId: server.id) else {
            throw AuthError.noTokensFound
        }
        
        if tokens.isExpired, let refreshToken = tokens.refreshToken {
            // Refresh token
            do {
                let newTokens = try await restClient.refreshAccessToken(
                    serverURL: server.url,
                    refreshToken: refreshToken,
                    clientId: HAAuthManager.defaultClientId
                )
                try await keychain.save(tokens: newTokens, forServerId: server.id)
                return newTokens.accessToken
            } catch {
                throw AuthError.tokenRefreshFailed(underlying: error)
            }
        }
        
        return tokens.accessToken
    }
    
    /// Stores tokens from an OAuth authorization code exchange
    public func completeOAuthLogin(server: ServerConfig, authCode: String) async throws -> AuthTokens {
        let tokens = try await restClient.exchangeAuthorizationCode(
            serverURL: server.url,
            code: authCode,
            clientId: HAAuthManager.defaultClientId
        )
        try await keychain.save(tokens: tokens, forServerId: server.id)
        return tokens
    }
    
    /// Stores a manually provided Long-Lived Access Token (LLAT)
    public func saveLongLivedToken(server: ServerConfig, token: String) async throws {
        let tokens = AuthTokens(
            accessToken: token,
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: nil // LLATs do not expire
        )
        try await keychain.save(tokens: tokens, forServerId: server.id)
    }
    
    /// Clears authentication credentials for a server
    public func logout(serverId: String) async {
        await keychain.deleteTokens(forServerId: serverId)
    }
    
    public func hasTokens(for serverId: String) async -> Bool {
        (try? await keychain.retrieveTokens(forServerId: serverId)) != nil
    }
    
    public enum AuthError: Error, LocalizedError {
        case noTokensFound
        case tokenRefreshFailed(underlying: Error)
        
        public var errorDescription: String? {
            switch self {
            case .noTokensFound:
                return "No authentication tokens found for this server. Please log in again."
            case .tokenRefreshFailed(let err):
                return "Failed to refresh authentication token: \(err.localizedDescription)"
            }
        }
    }
}
