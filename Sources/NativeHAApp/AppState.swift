import SwiftUI
import Observation
import NativeHACore
#if os(iOS)
import UIKit
#endif

@Observable
@MainActor
public final class AppState {
    public let serverStore: ServerStore
    public var connectionState: HAConnectionState = .disconnected
    public var isConfigured: Bool = false
    
    public let entityStore: EntityStore
    public let dashboardRepository: DashboardRepository
    public let wsClient: HAWebSocketClient
    
    public var isShowingSettings: Bool = false
    public var isShowingAddServerSheet: Bool = false
    public var presentedMoreInfoEntityId: String? = nil
    
    public init(serverStore: ServerStore = .shared) {
        self.serverStore = serverStore
        let client = HAWebSocketClient()
        self.wsClient = client
        self.entityStore = EntityStore(wsClient: client)
        self.dashboardRepository = DashboardRepository(wsClient: client)
        
        if let server = serverStore.activeServer {
            self.isConfigured = true
            self.entityStore.serverURL = server.url
            self.dashboardRepository.serverId = server.id
            if server.isDemo {
                self.entityStore.loadDemoData()
                self.dashboardRepository.loadDemoDashboards()
                self.connectionState = .connected(haVersion: "2026.8.0 (Demo)")
            }
        }
        
        setupWebSocketListener()
        syncQuickActions()
        
        // Handle Launch Arguments for automated testing & screenshot generation
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo") {
            enableDemoMode()
        }
        if let viewIndex = args.firstIndex(of: "-view"), viewIndex + 1 < args.count {
            let viewName = args[viewIndex + 1]
            self.dashboardRepository.selectedViewId = viewName
        }
        if let moreInfoIndex = args.firstIndex(of: "-more_info"), moreInfoIndex + 1 < args.count {
            let entityId = args[moreInfoIndex + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.presentedMoreInfoEntityId = entityId
            }
        }
        if args.contains("-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.isShowingSettings = true
            }
        }
    }
    
    public var activeServer: ServerConfig? {
        serverStore.activeServer
    }
    
    public var servers: [ServerConfig] {
        serverStore.servers
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
                if self.activeServer?.isDemo == true {
                    self.connectionState = .connected(haVersion: "2026.8.0 (Demo)")
                    return
                }
                self.connectionState = state
                
                if state.isConnected {
                    await self.subscribeToEntities()
                    await self.dashboardRepository.loadDashboards()
                }
            }
        }
    }
    
    public func connect() async {
        guard let server = activeServer else { return }
        
        // Reset stores for clean state
        self.entityStore.serverURL = server.url
        self.dashboardRepository.serverId = server.id
        
        if server.isDemo {
            await wsClient.disconnect()
            self.entityStore.loadDemoData()
            self.dashboardRepository.loadDemoDashboards()
            self.connectionState = .connected(haVersion: "2026.8.0 (Demo)")
            syncQuickActions()
            return
        }
        
        self.entityStore.isDemoMode = false
        self.dashboardRepository.isDemoMode = false
        
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
        
        syncQuickActions()
    }
    
    public func enableDemoMode() {
        serverStore.addServer(ServerConfig.demoServer, makeActive: true)
        self.isConfigured = true
        self.isShowingAddServerSheet = false
        syncQuickActions()
        
        Task {
            await connect()
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
    
    // MARK: - Server Switching & Management
    
    public func switchToServer(id: String) {
        guard id != serverStore.activeServerId || !connectionState.isConnected else { return }
        
        Task {
            await wsClient.disconnect()
            serverStore.setActiveServer(id: id)
            self.dashboardRepository.serverId = id
            self.isConfigured = true
            syncQuickActions()
            await connect()
        }
    }
    
    public func addServerAndLogin(_ server: ServerConfig) {
        serverStore.addServer(server, makeActive: true)
        self.isConfigured = true
        self.isShowingAddServerSheet = false
        syncQuickActions()
        
        Task {
            await wsClient.disconnect()
            await connect()
        }
    }
    
    public func removeServer(id: String) {
        let isCurrent = (id == serverStore.activeServerId)
        
        Task {
            await HAAuthManager.shared.logout(serverId: id)
            if isCurrent {
                await wsClient.disconnect()
            }
            
            serverStore.removeServer(id: id)
            syncQuickActions()
            
            if serverStore.activeServer != nil {
                self.isConfigured = true
                await connect()
            } else {
                self.isConfigured = false
                self.connectionState = .disconnected
            }
        }
    }
    
    public func logoutCurrentServer() {
        if let current = activeServer {
            removeServer(id: current.id)
        }
    }
    
    #if os(iOS)
    public func handleQuickAction(shortcutItem: UIApplicationShortcutItem) {
        if QuickActionManager.shared.isAddServerAction(shortcutItem) {
            isShowingAddServerSheet = true
        } else if let serverId = QuickActionManager.shared.extractServerId(from: shortcutItem) {
            switchToServer(id: serverId)
        }
    }
    #endif
    
    public func syncQuickActions() {
        #if os(iOS)
        QuickActionManager.shared.syncQuickActions(
            servers: serverStore.servers,
            activeServerId: serverStore.activeServerId
        )
        #endif
    }
    public func handleDeepLink(_ url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let host = url.host ?? ""
        
        if host == "demo" || url.scheme == "haven" {
            if activeServer?.isDemo != true {
                enableDemoMode()
            }
            
            // Check view selection: ?view=home / ?view=security / ?view=energy
            if let viewParam = queryItems.first(where: { $0.name == "view" })?.value {
                dashboardRepository.selectedViewId = viewParam
            }
            
            // Check more info: ?more_info=light.living_room_ceiling
            if let entityParam = queryItems.first(where: { $0.name == "more_info" })?.value {
                presentedMoreInfoEntityId = entityParam
            } else if queryItems.contains(where: { $0.name == "more_info" && $0.value == "" }) {
                presentedMoreInfoEntityId = nil
            }
            
            // Check settings: ?settings=true
            if let settingsParam = queryItems.first(where: { $0.name == "settings" })?.value {
                isShowingSettings = (settingsParam == "true" || settingsParam == "1")
            }
        }
    }
}

extension HAWebSocketClient {
    func setOnStateChanged(_ handler: @escaping @Sendable (HAConnectionState) -> Void) {
        self.onStateChanged = handler
    }
}
