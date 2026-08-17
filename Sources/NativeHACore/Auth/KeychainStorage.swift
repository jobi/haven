import Foundation
import Security

public actor KeychainStorage {
    public static let shared = KeychainStorage()
    
    private let serviceName = "com.nativeha.auth"
    
    public init() {}
    
    public func save(tokens: AuthTokens, forServerId serverId: String) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(tokens)
        let account = "ha_tokens_\(serverId)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Try deleting existing first to avoid duplicate item errors
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // If Keychain returns errSecMissingEntitlement (-34018) or fails in simulator environment,
            // fall back to UserDefaults storage
            UserDefaults.standard.set(data, forKey: "fallback_\(account)")
        } else {
            // Also keep fallback in sync
            UserDefaults.standard.set(data, forKey: "fallback_\(account)")
        }
    }
    
    public func retrieveTokens(forServerId serverId: String) throws -> AuthTokens? {
        let account = "ha_tokens_\(serverId)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            let decoder = JSONDecoder()
            return try? decoder.decode(AuthTokens.self, from: data)
        }
        
        // Fallback to UserDefaults if Keychain is unavailable (e.g. Simulator -34018)
        if let fallbackData = UserDefaults.standard.data(forKey: "fallback_\(account)") {
            let decoder = JSONDecoder()
            return try? decoder.decode(AuthTokens.self, from: fallbackData)
        }
        
        return nil
    }
    
    public func deleteTokens(forServerId serverId: String) {
        let account = "ha_tokens_\(serverId)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "fallback_\(account)")
    }
    
    public enum KeychainError: Error, LocalizedError {
        case failedToSave(status: OSStatus)
        case failedToRetrieve(status: OSStatus)
        
        public var errorDescription: String? {
            switch self {
            case .failedToSave(let status):
                return "Failed to save tokens in Keychain (OSStatus: \(status))"
            case .failedToRetrieve(let status):
                return "Failed to retrieve tokens from Keychain (OSStatus: \(status))"
            }
        }
    }
}
