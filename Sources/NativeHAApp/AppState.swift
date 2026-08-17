import SwiftUI
import Observation
import NativeHACore

@Observable
@MainActor
public final class AppState {
    public var activeServer: ServerConfig?
    public var connectionState: HAConnectionState = .disconnected
    public var isConfigured: Bool = false
    
    public let entityStore: EntityStore
    public let dashboardRepository: DashboardRepository
    public let wsClient: HAWebSocketClient
    
    public var isShowingSettings: Bool = false
    
    private let userDefaultsServerKey = "nativeha_active_server_v1"
    
    public init() {
        let client = HAWebSocketClient()
        self.wsClient = client
        self.entityStore = EntityStore(wsClient: client)
        self.dashboardRepository = DashboardRepository(wsClient: client)
        
        // Restore saved server from UserDefaults if available
        if let data = UserDefaults.standard.data(forKey: userDefaultsServerKey),
           let server = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            self.activeServer = server
            self.isConfigured = true
            self.entityStore.serverURL = server.url
        }
        
        setupWebSocketListener()
    }
    
    private func setupWebSocketListener() {
        Task {
            await attachStateListener()
        }
    }
    
    private func attachStateListener() async {
        await wsClient.setOnStateChanged { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.connectionState = state
                
                if state.isConnected {
                    // Subscribe to entity updates
                    await self.subscribeToEntities()
                    // Load dashboards
                    await self.dashboardRepository.loadDashboards()
                }
            }
        }
    }
    
    public func connect() async {
        guard let server = activeServer else { return }
        
        await attachStateListener()
        
        await wsClient.connect(server: server) { [weak self] in
            guard let server = await self?.activeServer else {
                throw HAAuthManager.AuthError.noTokensFound
            }
            return try await HAAuthManager.shared.getValidAccessToken(for: server)
        }
        
        let currentState = await wsClient.state
        self.connectionState = currentState
        if currentState.isConnected {
            await self.subscribeToEntities()
            await self.dashboardRepository.loadDashboards()
        }
    }
    
    private func subscribeToEntities() async {
        do {
            _ = try await wsClient.subscribe(type: "subscribe_entities") { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.entityStore.processEntityEvent(event)
                }
            }
        } catch {
            print("[AppState] Failed to subscribe to entities: \(error)")
        }
    }
    
    public func setServerAndLogin(_ server: ServerConfig) {
        self.activeServer = server
        self.isConfigured = true
        self.entityStore.serverURL = server.url
        
        if let data = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(data, forKey: userDefaultsServerKey)
        }
        
        Task {
            await connect()
        }
    }
    
    public func logout() {
        if let server = activeServer {
            Task {
                await HAAuthManager.shared.logout(serverId: server.id)
            }
        }
        
        Task {
            await wsClient.disconnect()
        }
        
        UserDefaults.standard.removeObject(forKey: userDefaultsServerKey)
        self.activeServer = nil
        self.isConfigured = false
        self.connectionState = .disconnected
    }
}

extension HAWebSocketClient {
    func setOnStateChanged(_ handler: @escaping @Sendable (HAConnectionState) -> Void) {
        self.onStateChanged = handler
    }
}
