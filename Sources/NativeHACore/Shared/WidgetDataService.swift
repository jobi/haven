import Foundation

/// Data & action service used by HavenWidgets and AppIntents to fetch live entity states
/// and execute Home Assistant service calls directly over REST (or Demo Mode),
/// scoped to a specific pinned server so switching servers in the main app never alters widgets.
public actor WidgetDataService {
    public static let shared = WidgetDataService()
    
    private let restClient: HARestClient
    private let authManager: HAAuthManager
    
    public init(
        restClient: HARestClient = HARestClient(),
        authManager: HAAuthManager = .shared
    ) {
        self.restClient = restClient
        self.authManager = authManager
    }
    
    // MARK: - Server Discovery
    
    /// Returns all configured Home Assistant servers (or the Demo server if none are configured).
    public func availableServers() -> [ServerConfig] {
        let store = ServerStore(userDefaults: SharedAppGroup.userDefaults)
        if !store.servers.isEmpty {
            return store.servers
        }
        return [ServerConfig.demoServer]
    }
    
    /// Returns the currently active server in the main app (used as default for brand-new widgets).
    public func activeServer() -> ServerConfig? {
        let store = ServerStore(userDefaults: SharedAppGroup.userDefaults)
        return store.activeServer
    }
    
    /// Resolves a pinned serverId to its `ServerConfig`.
    /// When `serverId` is explicitly specified, only that exact server is matched.
    public func resolveServer(for serverId: String?) -> ServerConfig? {
        let store = ServerStore(userDefaults: SharedAppGroup.userDefaults)
        if let serverId, !serverId.isEmpty {
            if serverId == ServerConfig.demoServer.id {
                return store.servers.first(where: { $0.id == serverId }) ?? ServerConfig.demoServer
            }
            return store.servers.first(where: { $0.id == serverId })
        }
        return store.activeServer
    }
    
    // MARK: - Entity Queries
    
    /// Returns the list of entities available to pick in Widget configuration for a specific server.
    public func availableEntities(forServerId serverId: String? = nil) async -> [WidgetEntitySnapshot] {
        let server = resolveServer(for: serverId)
        
        // 1. If Demo Mode or no server configured, return demo entities with any interactive overrides
        if server == nil || server?.isDemo == true {
            return demoSnapshots(serverId: server?.id ?? ServerConfig.demoServer.id)
        }
        
        guard let server else { return [] }
        
        // 2. Prefer cached per-server snapshots written by the main app for instant picker responsiveness
        let cached = SharedAppGroup.loadEntitySnapshots(forServerId: server.id)
        if !cached.isEmpty {
            return cached.sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
        }
        
        // 3. Otherwise fetch live from that specific server's Home Assistant REST API
        if let token = try? await authManager.getValidAccessToken(for: server),
           let states = try? await restClient.fetchAllStates(serverURL: server.url, token: token) {
            let snapshots = states
                .filter { Self.isWidgetRelevantDomain($0.domain) }
                .map { WidgetEntitySnapshot(from: $0, serverId: server.id) }
                .sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
            SharedAppGroup.saveEntitySnapshots(snapshots, forServerId: server.id)
            return snapshots
        }
        
        return []
    }
    
    /// Returns a sensible default set of entities for a server when a user first adds a widget.
    public func defaultEntities(forServerId serverId: String? = nil, limit: Int = 4) async -> [WidgetEntitySnapshot] {
        let all = await availableEntities(forServerId: serverId)
        let preferredDomains = ["light", "switch", "climate", "lock", "cover", "scene", "sensor"]
        var picked: [WidgetEntitySnapshot] = []
        
        for domain in preferredDomains {
            for entity in all where entity.domain == domain {
                if !picked.contains(where: { $0.entityId == entity.entityId }) {
                    picked.append(entity)
                    if picked.count >= limit { return picked }
                }
            }
        }
        
        for entity in all where !picked.contains(where: { $0.entityId == entity.entityId }) {
            picked.append(entity)
            if picked.count >= limit { break }
        }
        
        return picked
    }
    
    /// Fetches the latest snapshot for a single entity on a specific server, falling back to that server's cache when offline.
    public func fetchSnapshot(for entityId: String, serverId: String? = nil) async -> WidgetEntitySnapshot? {
        let server = resolveServer(for: serverId)
        
        if server == nil || server?.isDemo == true {
            let demoId = server?.id ?? ServerConfig.demoServer.id
            return demoSnapshots(serverId: demoId).first(where: { $0.entityId == entityId })
        }
        
        guard let server else { return nil }
        
        if let token = try? await authManager.getValidAccessToken(for: server),
           let live = try? await restClient.fetchEntityState(serverURL: server.url, token: token, entityId: entityId) {
            let snapshot = WidgetEntitySnapshot(from: live, serverId: server.id)
            SharedAppGroup.updateEntitySnapshot(snapshot, forServerId: server.id)
            return snapshot
        }
        
        return SharedAppGroup.loadEntitySnapshots(forServerId: server.id)
            .first(where: { $0.entityId == entityId })
    }
    
    /// Fetches latest snapshots for multiple entities on a specific server concurrently.
    public func fetchSnapshots(for entityIds: [String], serverId: String? = nil) async -> [WidgetEntitySnapshot] {
        await withTaskGroup(of: (Int, WidgetEntitySnapshot?).self) { group in
            for (index, id) in entityIds.enumerated() {
                group.addTask {
                    let snapshot = await self.fetchSnapshot(for: id, serverId: serverId)
                    return (index, snapshot)
                }
            }
            
            var indexed: [(Int, WidgetEntitySnapshot)] = []
            for await (index, snapshot) in group {
                if let snapshot {
                    indexed.append((index, snapshot))
                }
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
    
    /// Toggles or triggers an entity directly from an interactive widget button on its pinned server.
    @discardableResult
    public func toggleEntity(entityId: String, serverId: String? = nil) async throws -> WidgetEntitySnapshot? {
        let server = resolveServer(for: serverId)
        let domain = entityId.split(separator: ".").first.map(String.init) ?? ""
        
        // Handle Demo Mode interactively
        if server == nil || server?.isDemo == true {
            let demoId = server?.id ?? ServerConfig.demoServer.id
            guard let current = demoSnapshots(serverId: demoId).first(where: { $0.entityId == entityId }) else {
                return nil
            }
            let nextState = Self.nextDemoState(for: current)
            SharedAppGroup.saveDemoStateOverride(entityId: entityId, state: nextState)
            return WidgetEntitySnapshot(
                entityId: current.entityId,
                serverId: demoId,
                friendlyName: current.friendlyName,
                domain: current.domain,
                state: nextState,
                icon: current.icon,
                unitOfMeasurement: current.unitOfMeasurement
            )
        }
        
        guard let server else { return nil }
        let token = try await authManager.getValidAccessToken(for: server)
        
        // Determine current state to pick the right service for lock/cover
        let current = await fetchSnapshot(for: entityId, serverId: server.id)
        let (serviceDomain, serviceName) = Self.serviceCall(for: domain, currentState: current?.state)
        
        try await restClient.callService(
            serverURL: server.url,
            token: token,
            domain: serviceDomain,
            service: serviceName,
            entityId: entityId
        )
        
        // Brief pause so Home Assistant commits the new state before we re-fetch it
        try? await Task.sleep(nanoseconds: 250_000_000)
        return await fetchSnapshot(for: entityId, serverId: server.id)
    }
    
    // MARK: - Helpers
    
    public static func serviceCall(for domain: String, currentState: String?) -> (domain: String, service: String) {
        let lower = currentState?.lowercased() ?? ""
        switch domain {
        case "lock":
            return ("lock", lower == "locked" ? "unlock" : "lock")
        case "cover":
            return ("cover", (lower == "open" || lower == "opening") ? "close_cover" : "open_cover")
        case "scene", "script":
            return (domain, "turn_on")
        case "media_player":
            return ("media_player", "media_play_pause")
        case "light", "switch", "fan", "input_boolean", "automation":
            return (domain, "toggle")
        default:
            return ("homeassistant", "toggle")
        }
    }
    
    private static func nextDemoState(for snapshot: WidgetEntitySnapshot) -> String {
        switch snapshot.domain {
        case "lock":
            return snapshot.state.lowercased() == "locked" ? "unlocked" : "locked"
        case "cover":
            return snapshot.state.lowercased() == "open" ? "closed" : "open"
        case "media_player":
            return snapshot.state.lowercased() == "playing" ? "paused" : "playing"
        case "scene", "script":
            return "active"
        default:
            return snapshot.state.lowercased() == "on" ? "off" : "on"
        }
    }
    
    public static func isWidgetRelevantDomain(_ domain: String) -> Bool {
        switch domain {
        case "light", "switch", "fan", "input_boolean", "lock", "cover",
             "climate", "sensor", "binary_sensor", "scene", "script",
             "automation", "media_player", "weather":
            return true
        default:
            return false
        }
    }
    
    private func demoSnapshots(serverId: String) -> [WidgetEntitySnapshot] {
        let overrides = SharedAppGroup.loadDemoStateOverrides()
        return DemoDataProvider.shared.generateDemoEntities().values
            .filter { Self.isWidgetRelevantDomain($0.domain) }
            .map { entity in
                let overrideState = overrides[entity.entityId] ?? entity.state
                return WidgetEntitySnapshot(
                    entityId: entity.entityId,
                    serverId: serverId,
                    friendlyName: entity.friendlyName,
                    domain: entity.domain,
                    state: overrideState,
                    icon: entity.icon,
                    unitOfMeasurement: entity.unitOfMeasurement
                )
            }
            .sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
    }
}
