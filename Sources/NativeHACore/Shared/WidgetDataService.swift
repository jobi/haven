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
    
    /// Returns entities grouped by every configured server (for multi-server searchable widget pickers).
    public func allServersEntities() async -> [(server: ServerConfig, entities: [WidgetEntitySnapshot])] {
        let servers = availableServers()
        return await withTaskGroup(of: (Int, ServerConfig, [WidgetEntitySnapshot]).self) { group in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    let entities = await self.availableEntities(forServerId: server.id)
                    return (index, server, entities)
                }
            }
            var indexed: [(Int, ServerConfig, [WidgetEntitySnapshot])] = []
            for await item in group where !item.2.isEmpty {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map { (server: $0.1, entities: $0.2) }
        }
    }
        
    /// Returns only multi-choice entities (`remote` with `activity_list`, `select`, `input_select`)
    /// grouped by server, for the Activity & Option Picker widget.
    /// Automatically falls back to a live REST fetch if the cached snapshots don't include multi-choice options yet.
    public func allServersMultiChoiceEntities() async -> [(server: ServerConfig, entities: [WidgetEntitySnapshot])] {
        let servers = availableServers()
        return await withTaskGroup(of: (Int, ServerConfig, [WidgetEntitySnapshot]).self) { group in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    var entities = await self.availableEntities(forServerId: server.id)
                    var multi = entities.filter { $0.hasOptions }
                    
                    // If cache had no multi-choice entities yet, do a live REST refresh for this server
                    if multi.isEmpty && !server.isDemo {
                        if let refreshed = await self.refreshEntitiesFromREST(for: server) {
                            entities = refreshed
                            multi = entities.filter { $0.hasOptions }
                        }
                    }
                    return (index, server, multi)
                }
            }
            var indexed: [(Int, ServerConfig, [WidgetEntitySnapshot])] = []
            for await item in group where !item.2.isEmpty {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map { (server: $0.1, entities: $0.2) }
        }
    }
        
    private func refreshEntitiesFromREST(for server: ServerConfig) async -> [WidgetEntitySnapshot]? {
        guard let token = try? await authManager.getValidAccessToken(for: server),
              let states = try? await restClient.fetchAllStates(serverURL: server.url, token: token) else {
            return nil
        }
        let snapshots = states
            .filter { Self.isWidgetRelevantDomain($0.domain) }
            .map { WidgetEntitySnapshot(from: $0, serverId: server.id) }
            .sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
        SharedAppGroup.saveEntitySnapshots(snapshots, forServerId: server.id)
        return snapshots
    }
    
    /// Returns all `climate` (thermostat) entities grouped by server.
    public func allServersClimateEntities() async -> [(server: ServerConfig, entities: [WidgetEntitySnapshot])] {
        let servers = availableServers()
        return await withTaskGroup(of: (Int, ServerConfig, [WidgetEntitySnapshot]).self) { group in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    var entities = await self.availableEntities(forServerId: server.id)
                    var climates = entities.filter { $0.domain == "climate" }
                    
                    if (climates.isEmpty || climates.allSatisfy { $0.hvacModes == nil && $0.currentTemperature == nil }) && !server.isDemo {
                        if let refreshed = await self.refreshEntitiesFromREST(for: server) {
                            entities = refreshed
                            climates = entities.filter { $0.domain == "climate" }
                        }
                    }
                    return (index, server, climates)
                }
            }
            var indexed: [(Int, ServerConfig, [WidgetEntitySnapshot])] = []
            for await item in group where !item.2.isEmpty {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map { (server: $0.1, entities: $0.2) }
        }
    }
    
    /// Returns all `media_player` entities grouped by server.
    public func allServersMediaPlayerEntities() async -> [(server: ServerConfig, entities: [WidgetEntitySnapshot])] {
        let servers = availableServers()
        return await withTaskGroup(of: (Int, ServerConfig, [WidgetEntitySnapshot]).self) { group in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    var entities = await self.availableEntities(forServerId: server.id)
                    var players = entities.filter { $0.domain == "media_player" }
                    
                    if players.isEmpty && !server.isDemo {
                        if let refreshed = await self.refreshEntitiesFromREST(for: server) {
                            entities = refreshed
                            players = entities.filter { $0.domain == "media_player" }
                        }
                    }
                    return (index, server, players)
                }
            }
            var indexed: [(Int, ServerConfig, [WidgetEntitySnapshot])] = []
            for await item in group where !item.2.isEmpty {
                indexed.append(item)
            }
            return indexed.sorted { $0.0 < $1.0 }.map { (server: $0.1, entities: $0.2) }
        }
    }
    
    /// Downloads album artwork bytes for a `media_player` snapshot so WidgetKit can render it synchronously.
    public func fetchArtworkData(for snapshot: WidgetEntitySnapshot) async -> Data? {
        guard let pic = snapshot.entityPicture, !pic.isEmpty else { return nil }
        guard let server = resolveServer(for: snapshot.serverId), !server.isDemo else { return nil }
        
        let artworkURL: URL?
        if pic.hasPrefix("http://") || pic.hasPrefix("https://") {
            artworkURL = URL(string: pic)
        } else {
            artworkURL = URL(string: pic, relativeTo: server.url)?.absoluteURL
        }
        guard let url = artworkURL else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        if let token = try? await authManager.getValidAccessToken(for: server) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        return data
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
    
    /// Selects a specific option or remote activity (e.g. Harmony remote activity, `select`, `input_select`)
    /// directly from an interactive widget button on its pinned server.
    @discardableResult
    public func selectOption(entityId: String, option: String, serverId: String? = nil) async throws -> WidgetEntitySnapshot? {
        let server = resolveServer(for: serverId)
        let domain = entityId.split(separator: ".").first.map(String.init) ?? "select"
        
        // Handle Demo Mode interactively
        if server == nil || server?.isDemo == true {
            let demoId = server?.id ?? ServerConfig.demoServer.id
            SharedAppGroup.saveDemoStateOverride(entityId: entityId, state: option)
            if let current = demoSnapshots(serverId: demoId).first(where: { $0.entityId == entityId }) {
                return WidgetEntitySnapshot(
                    entityId: current.entityId,
                    serverId: demoId,
                    friendlyName: current.friendlyName,
                    domain: current.domain,
                    state: (domain == "remote" && (option.lowercased() == "poweroff" || option.lowercased() == "off")) ? "off" : (domain == "remote" ? "on" : option),
                    icon: current.icon,
                    unitOfMeasurement: current.unitOfMeasurement,
                    options: current.options,
                    currentOption: option
                )
            }
            return nil
        }
        
        guard let server else { return nil }
        let token = try await authManager.getValidAccessToken(for: server)
        
        let (serviceDomain, serviceName, serviceData) = Self.optionServiceCall(for: domain, option: option)
        try await restClient.callService(
            serverURL: server.url,
            token: token,
            domain: serviceDomain,
            service: serviceName,
            entityId: entityId,
            serviceData: serviceData
        )
        
        // Immediately save an optimistic snapshot so slow hubs (like Harmony) reflect the chosen activity right away
        let cached = SharedAppGroup.loadEntitySnapshots(forServerId: server.id)
            .first(where: { $0.entityId == entityId })
        let lowerOpt = option.lowercased()
        let isPowerOff = (domain == "remote") && (lowerOpt == "poweroff" || lowerOpt == "power_off" || lowerOpt == "off")
        let optimisticState = (domain == "remote") ? (isPowerOff ? "off" : "on") : option
        let optimisticSnapshot = WidgetEntitySnapshot(
            entityId: entityId,
            serverId: server.id,
            friendlyName: cached?.friendlyName ?? entityId,
            domain: domain,
            state: optimisticState,
            icon: cached?.icon,
            unitOfMeasurement: cached?.unitOfMeasurement,
            options: cached?.options,
            currentOption: option
        )
        SharedAppGroup.updateEntitySnapshot(optimisticSnapshot, forServerId: server.id)
        
        // Wait briefly for Home Assistant to commit, and only overwrite if HA reports the updated option
        try? await Task.sleep(nanoseconds: 800_000_000)
        if let live = try? await restClient.fetchEntityState(serverURL: server.url, token: token, entityId: entityId) {
            let liveSnapshot = WidgetEntitySnapshot(from: live, serverId: server.id)
            let liveCurrent = (liveSnapshot.currentOption ?? liveSnapshot.state).trimmingCharacters(in: .whitespacesAndNewlines)
            if liveCurrent.caseInsensitiveCompare(option) == .orderedSame || (isPowerOff && !liveSnapshot.isActive) {
                SharedAppGroup.updateEntitySnapshot(liveSnapshot, forServerId: server.id)
                return liveSnapshot
            }
        }
        return optimisticSnapshot
    }
    
    /// Adjusts the target temperature of a climate entity by `delta` (supporting both single-setpoint and heat_cool dual-setpoint).
    @discardableResult
    public func adjustClimateTemperature(
        entityId: String,
        delta: Double,
        serverId: String? = nil
    ) async throws -> WidgetEntitySnapshot? {
        let server = resolveServer(for: serverId)
        guard let current = await fetchSnapshot(for: entityId, serverId: server?.id) else {
            return nil
        }
        
        let isDual = (current.targetTemperature == nil && current.targetTempLow != nil && current.targetTempHigh != nil)
        let newTarget = current.targetTemperature.map { ($0 + delta).rounded(toStep: current.effectiveTemperatureStep) }
        let newLow = current.targetTempLow.map { ($0 + delta).rounded(toStep: current.effectiveTemperatureStep) }
        let newHigh = current.targetTempHigh.map { ($0 + delta).rounded(toStep: current.effectiveTemperatureStep) }
        
        var serviceData: [String: AnyCodable] = [:]
        if isDual, let low = newLow, let high = newHigh {
            serviceData["target_temp_low"] = AnyCodable(low)
            serviceData["target_temp_high"] = AnyCodable(high)
        } else if let temp = newTarget ?? current.currentTemperature.map({ ($0 + delta).rounded(toStep: current.effectiveTemperatureStep) }) {
            serviceData["temperature"] = AnyCodable(temp)
        } else {
            return current
        }
        
        let optimistic = WidgetEntitySnapshot(
            entityId: current.entityId,
            serverId: current.serverId,
            friendlyName: current.friendlyName,
            domain: current.domain,
            state: current.state,
            icon: current.icon,
            unitOfMeasurement: current.unitOfMeasurement,
            options: current.options,
            currentOption: current.currentOption,
            currentTemperature: current.currentTemperature,
            targetTemperature: isDual ? nil : (newTarget ?? current.targetTemperature),
            targetTempLow: isDual ? newLow : current.targetTempLow,
            targetTempHigh: isDual ? newHigh : current.targetTempHigh,
            hvacAction: current.hvacAction,
            hvacModes: current.hvacModes,
            temperatureStep: current.temperatureStep
        )
        
        if server == nil || server?.isDemo == true {
            return optimistic
        }
        
        guard let server else { return optimistic }
        let token = try await authManager.getValidAccessToken(for: server)
        try await restClient.callService(
            serverURL: server.url,
            token: token,
            domain: "climate",
            service: "set_temperature",
            entityId: entityId,
            serviceData: serviceData
        )
        
        SharedAppGroup.updateEntitySnapshot(optimistic, forServerId: server.id)
        try? await Task.sleep(nanoseconds: 500_000_000)
        if let live = try? await restClient.fetchEntityState(serverURL: server.url, token: token, entityId: entityId) {
            let liveSnapshot = WidgetEntitySnapshot(from: live, serverId: server.id)
            SharedAppGroup.updateEntitySnapshot(liveSnapshot, forServerId: server.id)
            return liveSnapshot
        }
        return optimistic
    }
    
    /// Sets the HVAC mode (`off`, `heat`, `cool`, `heat_cool`, `auto`, etc.) of a climate entity.
    @discardableResult
    public func setClimateHVACMode(
        entityId: String,
        mode: String,
        serverId: String? = nil
    ) async throws -> WidgetEntitySnapshot? {
        let server = resolveServer(for: serverId)
        let cached = server.flatMap { s in
            SharedAppGroup.loadEntitySnapshots(forServerId: s.id).first(where: { $0.entityId == entityId })
        }
        
        let optimistic = WidgetEntitySnapshot(
            entityId: entityId,
            serverId: server?.id,
            friendlyName: cached?.friendlyName ?? entityId,
            domain: "climate",
            state: mode,
            icon: cached?.icon,
            unitOfMeasurement: cached?.unitOfMeasurement,
            options: cached?.options,
            currentOption: cached?.currentOption,
            currentTemperature: cached?.currentTemperature,
            targetTemperature: cached?.targetTemperature,
            targetTempLow: cached?.targetTempLow,
            targetTempHigh: cached?.targetTempHigh,
            hvacAction: mode == "off" ? "off" : cached?.hvacAction,
            hvacModes: cached?.hvacModes,
            temperatureStep: cached?.temperatureStep
        )
        
        if server == nil || server?.isDemo == true {
            SharedAppGroup.saveDemoStateOverride(entityId: entityId, state: mode)
            return optimistic
        }
        
        guard let server else { return optimistic }
        let token = try await authManager.getValidAccessToken(for: server)
        try await restClient.callService(
            serverURL: server.url,
            token: token,
            domain: "climate",
            service: "set_hvac_mode",
            entityId: entityId,
            serviceData: ["hvac_mode": AnyCodable(mode)]
        )
        
        SharedAppGroup.updateEntitySnapshot(optimistic, forServerId: server.id)
        try? await Task.sleep(nanoseconds: 500_000_000)
        if let live = try? await restClient.fetchEntityState(serverURL: server.url, token: token, entityId: entityId) {
            let liveSnapshot = WidgetEntitySnapshot(from: live, serverId: server.id)
            if liveSnapshot.state.caseInsensitiveCompare(mode) == .orderedSame {
                SharedAppGroup.updateEntitySnapshot(liveSnapshot, forServerId: server.id)
                return liveSnapshot
            }
        }
        return optimistic
    }
    
    /// Executes a playback or volume command (`play_pause`, `previous`, `next`, `volume_up`, `volume_down`, `mute_toggle`, `power_toggle`)
    /// on a `media_player` entity.
    @discardableResult
    public func performMediaCommand(
        entityId: String,
        command: String,
        serverId: String? = nil
    ) async throws -> WidgetEntitySnapshot? {
        let server = resolveServer(for: serverId)
        let current = await fetchSnapshot(for: entityId, serverId: server?.id)
        
        let serviceName: String
        var serviceData: [String: AnyCodable]? = nil
        var nextState = current?.state ?? "playing"
        var nextVolume = current?.volumeLevel
        var nextMuted = current?.isVolumeMuted
        
        switch command {
        case "play_pause":
            serviceName = "media_play_pause"
            nextState = (current?.state.lowercased() == "playing") ? "paused" : "playing"
        case "previous":
            serviceName = "media_previous_track"
        case "next":
            serviceName = "media_next_track"
        case "volume_up":
            serviceName = "volume_up"
            if let v = current?.volumeLevel { nextVolume = min(1.0, v + 0.05) }
        case "volume_down":
            serviceName = "volume_down"
            if let v = current?.volumeLevel { nextVolume = max(0.0, v - 0.05) }
        case "mute_toggle":
            serviceName = "volume_mute"
            let targetMute = !(current?.isVolumeMuted ?? false)
            serviceData = ["is_volume_muted": AnyCodable(targetMute)]
            nextMuted = targetMute
        case "power_toggle":
            serviceName = (current?.state.lowercased() == "off") ? "turn_on" : "turn_off"
            nextState = (current?.state.lowercased() == "off") ? "idle" : "off"
        default:
            serviceName = "media_play_pause"
        }
        
        let optimistic = WidgetEntitySnapshot(
            entityId: entityId,
            serverId: server?.id,
            friendlyName: current?.friendlyName ?? entityId,
            domain: "media_player",
            state: nextState,
            icon: current?.icon,
            unitOfMeasurement: current?.unitOfMeasurement,
            mediaTitle: current?.mediaTitle,
            mediaArtist: current?.mediaArtist,
            entityPicture: current?.entityPicture,
            volumeLevel: nextVolume,
            isVolumeMuted: nextMuted
        )
        
        if server == nil || server?.isDemo == true {
            SharedAppGroup.saveDemoStateOverride(entityId: entityId, state: nextState)
            return optimistic
        }
        
        guard let server else { return optimistic }
        let token = try await authManager.getValidAccessToken(for: server)
        try await restClient.callService(
            serverURL: server.url,
            token: token,
            domain: "media_player",
            service: serviceName,
            entityId: entityId,
            serviceData: serviceData
        )
        
        SharedAppGroup.updateEntitySnapshot(optimistic, forServerId: server.id)
        try? await Task.sleep(nanoseconds: 500_000_000)
        if let live = try? await restClient.fetchEntityState(serverURL: server.url, token: token, entityId: entityId) {
            let liveSnapshot = WidgetEntitySnapshot(from: live, serverId: server.id)
            SharedAppGroup.updateEntitySnapshot(liveSnapshot, forServerId: server.id)
            return liveSnapshot
        }
        return optimistic
    }
    
    // MARK: - Helpers
    
    public static func optionServiceCall(
        for domain: String,
        option: String
    ) -> (domain: String, service: String, serviceData: [String: AnyCodable]?) {
        if domain == "remote" {
            let lower = option.lowercased()
            if lower == "poweroff" || lower == "power_off" || lower == "off" {
                return ("remote", "turn_off", nil)
            }
            return ("remote", "turn_on", ["activity": AnyCodable(option)])
        }
        return (domain, "select_option", ["option": AnyCodable(option)])
    }
    
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
        case "light", "switch", "fan", "input_boolean", "automation", "remote":
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
             "automation", "media_player", "weather", "remote", "select", "input_select":
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
                let base = WidgetEntitySnapshot(from: entity, serverId: serverId)
                if let overrideState = overrides[entity.entityId] {
                    return WidgetEntitySnapshot(
                        entityId: base.entityId,
                        serverId: serverId,
                        friendlyName: base.friendlyName,
                        domain: base.domain,
                        state: overrideState,
                        icon: base.icon,
                        unitOfMeasurement: base.unitOfMeasurement,
                        options: base.options,
                        currentOption: base.options != nil ? overrideState : base.currentOption,
                        currentTemperature: base.currentTemperature,
                        targetTemperature: base.targetTemperature,
                        targetTempLow: base.targetTempLow,
                        targetTempHigh: base.targetTempHigh,
                        hvacAction: base.hvacAction,
                        hvacModes: base.hvacModes,
                        temperatureStep: base.temperatureStep
                    )
                }
                return base
            }
            .sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
    }
}

private extension Double {
    func rounded(toStep step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}
