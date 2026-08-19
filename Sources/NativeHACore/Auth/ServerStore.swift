import Foundation
import Observation

/// Manages multiple configured Home Assistant servers with persistence and active server tracking.
@Observable
public final class ServerStore: @unchecked Sendable {
    public static let shared = ServerStore()
    
    public private(set) var servers: [ServerConfig] = []
    public private(set) var activeServerId: String? = nil
    
    private let userDefaultsListKey = "haven_servers_list_v1"
    private let userDefaultsActiveKey = "haven_active_server_id_v1"
    private let legacyServerKey = "nativeha_active_server_v1"
    
    private let userDefaults: UserDefaults
    private let lock = NSLock()
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadFromStorage()
    }
    
    public var activeServer: ServerConfig? {
        guard let activeId = activeServerId else {
            return servers.first
        }
        return servers.first(where: { $0.id == activeId }) ?? servers.first
    }
    
    public var hasServers: Bool {
        !servers.isEmpty
    }
    
    // MARK: - Mutations
    
    public func addServer(_ server: ServerConfig, makeActive: Bool = true) {
        lock.lock()
        defer { lock.unlock() }
        
        if let idx = servers.firstIndex(where: { $0.id == server.id }) {
            servers[idx] = server
        } else {
            servers.append(server)
        }
        
        if makeActive || activeServerId == nil {
            activeServerId = server.id
        }
        
        saveToStorage()
    }
    
    public func updateServer(_ server: ServerConfig) {
        lock.lock()
        defer { lock.unlock() }
        
        if let idx = servers.firstIndex(where: { $0.id == server.id }) {
            servers[idx] = server
            saveToStorage()
        }
    }
    
    public func removeServer(id: String) {
        lock.lock()
        defer { lock.unlock() }
        
        servers.removeAll(where: { $0.id == id })
        
        if activeServerId == id {
            activeServerId = servers.first?.id
        }
        
        saveToStorage()
    }
    
    public func setActiveServer(id: String) {
        lock.lock()
        defer { lock.unlock() }
        
        if servers.contains(where: { $0.id == id }) {
            activeServerId = id
            saveToStorage()
        }
    }
    
    // MARK: - Persistence & Migration
    
    private func loadFromStorage() {
        // 1. Try loading modern multi-server list
        if let data = userDefaults.data(forKey: userDefaultsListKey),
           let loaded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            self.servers = loaded
            self.activeServerId = userDefaults.string(forKey: userDefaultsActiveKey) ?? loaded.first?.id
            return
        }
        
        // 2. Migrate legacy single-server configuration if present
        if let data = userDefaults.data(forKey: legacyServerKey),
           let legacyServer = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            self.servers = [legacyServer]
            self.activeServerId = legacyServer.id
            saveToStorage()
            return
        }
    }
    
    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(servers) {
            userDefaults.set(data, forKey: userDefaultsListKey)
        }
        userDefaults.set(activeServerId, forKey: userDefaultsActiveKey)
    }
}
