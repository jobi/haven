import Foundation

/// Shared container utilities for exchanging server configuration, auth tokens,
/// and per-server cached entity snapshots between the main Haven app and the HavenWidgets extension.
public enum SharedAppGroup {
    public static let identifier = "group.org.bilien.haven"
    public static let keychainAccessGroupSuffix = "org.bilien.haven"
    
    private static let legacyEntitySnapshotsKey = "haven_widget_entity_snapshots_v1"
    private static let perServerSnapshotsPrefix = "haven_widget_entity_snapshots_v5_"
    private static let demoOverridesKey = "haven_widget_demo_overrides_v1"
    
    public static var userDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
    
    private static func snapshotsKey(forServerId serverId: String) -> String {
        "\(perServerSnapshotsPrefix)\(serverId)"
    }
    
    // MARK: - Per-Server Entity Snapshot Cache
    
    public static func saveEntitySnapshots(_ snapshots: [WidgetEntitySnapshot], forServerId serverId: String) {
        let tagged = snapshots.map { snap in
            snap.serverId == serverId ? snap : snap.withServerId(serverId)
        }
        guard let data = try? JSONEncoder().encode(tagged) else { return }
        userDefaults.set(data, forKey: snapshotsKey(forServerId: serverId))
    }
    
    public static func loadEntitySnapshots(forServerId serverId: String) -> [WidgetEntitySnapshot] {
        if let data = userDefaults.data(forKey: snapshotsKey(forServerId: serverId)),
           let decoded = try? JSONDecoder().decode([WidgetEntitySnapshot].self, from: data) {
            return decoded.map { $0.serverId == nil ? $0.withServerId(serverId) : $0 }
        }
        return []
    }
    
    public static func updateEntitySnapshot(_ snapshot: WidgetEntitySnapshot, forServerId serverId: String) {
        let tagged = snapshot.serverId == serverId ? snapshot : snapshot.withServerId(serverId)
        var existing = loadEntitySnapshots(forServerId: serverId)
        if let idx = existing.firstIndex(where: { $0.entityId == tagged.entityId }) {
            existing[idx] = tagged
        } else {
            existing.append(tagged)
        }
        saveEntitySnapshots(existing, forServerId: serverId)
    }
    
    public static func removeEntitySnapshots(forServerId serverId: String) {
        userDefaults.removeObject(forKey: snapshotsKey(forServerId: serverId))
    }
    
    // MARK: - Legacy / Default Helpers (uses active server when no serverId specified)
    
    public static func saveEntitySnapshots(_ snapshots: [WidgetEntitySnapshot]) {
        if let activeId = ServerStore(userDefaults: userDefaults).activeServer?.id {
            saveEntitySnapshots(snapshots, forServerId: activeId)
        } else if let data = try? JSONEncoder().encode(snapshots) {
            userDefaults.set(data, forKey: legacyEntitySnapshotsKey)
        }
    }
    
    public static func loadEntitySnapshots() -> [WidgetEntitySnapshot] {
        if let activeId = ServerStore(userDefaults: userDefaults).activeServer?.id {
            let scoped = loadEntitySnapshots(forServerId: activeId)
            if !scoped.isEmpty { return scoped }
        }
        guard let data = userDefaults.data(forKey: legacyEntitySnapshotsKey),
              let decoded = try? JSONDecoder().decode([WidgetEntitySnapshot].self, from: data) else {
            return []
        }
        return decoded
    }
    
    public static func updateEntitySnapshot(_ snapshot: WidgetEntitySnapshot) {
        if let serverId = snapshot.serverId ?? ServerStore(userDefaults: userDefaults).activeServer?.id {
            updateEntitySnapshot(snapshot, forServerId: serverId)
        }
    }
    
    // MARK: - Demo Mode State Overrides (for interactive widgets in Demo Mode)
    
    public static func saveDemoStateOverride(entityId: String, state: String) {
        var overrides = loadDemoStateOverrides()
        overrides[entityId] = state
        userDefaults.set(overrides, forKey: demoOverridesKey)
    }
    
    public static func loadDemoStateOverrides() -> [String: String] {
        userDefaults.dictionary(forKey: demoOverridesKey) as? [String: String] ?? [:]
    }
}

/// Lightweight, Codable representation of a Home Assistant entity for WidgetKit & AppIntents.
public struct WidgetEntitySnapshot: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: String {
        if let serverId, !serverId.isEmpty {
            return "\(serverId)::\(entityId)"
        }
        return entityId
    }
    public let entityId: String
    public let serverId: String?
    public let friendlyName: String
    public let domain: String
    public let state: String
    public let icon: String?
    public let unitOfMeasurement: String?
    public let options: [String]?
    public let currentOption: String?
    public let currentTemperature: Double?
    public let targetTemperature: Double?
    public let targetTempLow: Double?
    public let targetTempHigh: Double?
    public let hvacAction: String?
    public let hvacModes: [String]?
    public let temperatureStep: Double?
    public let mediaTitle: String?
    public let mediaArtist: String?
    public let entityPicture: String?
    public let volumeLevel: Double?
    public let isVolumeMuted: Bool?
    public let lastUpdated: Date
    
    public init(
        entityId: String,
        serverId: String? = nil,
        friendlyName: String,
        domain: String,
        state: String,
        icon: String? = nil,
        unitOfMeasurement: String? = nil,
        options: [String]? = nil,
        currentOption: String? = nil,
        currentTemperature: Double? = nil,
        targetTemperature: Double? = nil,
        targetTempLow: Double? = nil,
        targetTempHigh: Double? = nil,
        hvacAction: String? = nil,
        hvacModes: [String]? = nil,
        temperatureStep: Double? = nil,
        mediaTitle: String? = nil,
        mediaArtist: String? = nil,
        entityPicture: String? = nil,
        volumeLevel: Double? = nil,
        isVolumeMuted: Bool? = nil,
        lastUpdated: Date = Date()
    ) {
        self.entityId = entityId
        self.serverId = serverId
        self.friendlyName = friendlyName
        self.domain = domain
        self.state = state
        self.icon = icon
        self.unitOfMeasurement = unitOfMeasurement
        self.options = options
        self.currentOption = currentOption
        self.currentTemperature = currentTemperature
        self.targetTemperature = targetTemperature
        self.targetTempLow = targetTempLow
        self.targetTempHigh = targetTempHigh
        self.hvacAction = hvacAction
        self.hvacModes = hvacModes
        self.temperatureStep = temperatureStep
        self.mediaTitle = mediaTitle
        self.mediaArtist = mediaArtist
        self.entityPicture = entityPicture
        self.volumeLevel = volumeLevel
        self.isVolumeMuted = isVolumeMuted
        self.lastUpdated = lastUpdated
    }
    
    public init(from entity: HAEntityState, serverId: String? = nil) {
        self.entityId = entity.entityId
        self.serverId = serverId
        self.friendlyName = entity.friendlyName
        self.domain = entity.domain
        self.state = entity.state
        self.icon = entity.icon
        self.unitOfMeasurement = entity.unitOfMeasurement
        
        let extractedOptions =
            entity.attributes["options"]?.arrayValue?.compactMap(\.stringValue) ??
            entity.attributes["activity_list"]?.arrayValue?.compactMap(\.stringValue)
        self.options = (extractedOptions?.isEmpty == false) ? extractedOptions : nil
        
        if entity.domain == "remote" {
            self.currentOption = entity.attributes["current_activity"]?.stringValue ?? entity.state
        } else if self.options != nil {
            self.currentOption = entity.state
        } else {
            self.currentOption = nil
        }
        
        if entity.domain == "climate" {
            self.currentTemperature = entity.attributes["current_temperature"]?.doubleValue
            self.targetTemperature = entity.attributes["temperature"]?.doubleValue
            self.targetTempLow = entity.attributes["target_temp_low"]?.doubleValue
            self.targetTempHigh = entity.attributes["target_temp_high"]?.doubleValue
            self.hvacAction = entity.attributes["hvac_action"]?.stringValue
            self.hvacModes = entity.attributes["hvac_modes"]?.arrayValue?.compactMap(\.stringValue)
            self.temperatureStep = entity.attributes["target_temp_step"]?.doubleValue
        } else {
            self.currentTemperature = nil
            self.targetTemperature = nil
            self.targetTempLow = nil
            self.targetTempHigh = nil
            self.hvacAction = nil
            self.hvacModes = nil
            self.temperatureStep = nil
        }
        
        if entity.domain == "media_player" {
            self.mediaTitle = entity.attributes["media_title"]?.stringValue
            self.mediaArtist =
                entity.attributes["media_artist"]?.stringValue ??
                entity.attributes["media_album_name"]?.stringValue ??
                entity.attributes["app_name"]?.stringValue
            self.entityPicture = entity.attributes["entity_picture"]?.stringValue
            self.volumeLevel = entity.attributes["volume_level"]?.doubleValue
            self.isVolumeMuted = entity.attributes["is_volume_muted"]?.boolValue
        } else {
            self.mediaTitle = nil
            self.mediaArtist = nil
            self.entityPicture = nil
            self.volumeLevel = nil
            self.isVolumeMuted = nil
        }
        
        self.lastUpdated = Date()
    }
    
    public func withServerId(_ serverId: String) -> WidgetEntitySnapshot {
        WidgetEntitySnapshot(
            entityId: entityId,
            serverId: serverId,
            friendlyName: friendlyName,
            domain: domain,
            state: state,
            icon: icon,
            unitOfMeasurement: unitOfMeasurement,
            options: options,
            currentOption: currentOption,
            currentTemperature: currentTemperature,
            targetTemperature: targetTemperature,
            targetTempLow: targetTempLow,
            targetTempHigh: targetTempHigh,
            hvacAction: hvacAction,
            hvacModes: hvacModes,
            temperatureStep: temperatureStep,
            mediaTitle: mediaTitle,
            mediaArtist: mediaArtist,
            entityPicture: entityPicture,
            volumeLevel: volumeLevel,
            isVolumeMuted: isVolumeMuted,
            lastUpdated: lastUpdated
        )
    }
    
    public var effectiveTemperatureStep: Double {
        if let step = temperatureStep, step > 0 { return step }
        let ref = targetTemperature ?? currentTemperature ?? 70.0
        return ref > 45.0 ? 1.0 : 0.5
    }
    
    public var hasOptions: Bool {
        guard let options else { return false }
        return !options.isEmpty
    }
    
    public var isActive: Bool {
        let lower = state.lowercased()
        switch domain {
        case "lock":
            return lower == "locked"
        case "cover":
            return lower == "open" || lower == "opening"
        case "climate":
            return lower != "off" && lower != "unavailable"
        case "remote":
            let act = currentOption?.lowercased() ?? ""
            return lower == "on" && act != "poweroff" && act != "power_off"
        case "select", "input_select":
            return lower != "off" && lower != "none" && lower != "unavailable" && lower != "unknown"
        default:
            return lower == "on" || lower == "playing" || lower == "home" || lower == "open"
        }
    }
    
    public var isControllable: Bool {
        switch domain {
        case "light", "switch", "fan", "input_boolean", "lock", "cover", "scene", "script", "automation", "media_player", "remote":
            return true
        default:
            return false
        }
    }
    
    public var formattedState: String {
        if domain == "remote", let current = currentOption, !current.isEmpty {
            let lower = current.lowercased()
            if lower == "poweroff" || lower == "power_off" || state.lowercased() == "off" {
                return "Off"
            }
            return current
        }
        if let unit = unitOfMeasurement, !unit.isEmpty {
            return "\(state) \(unit)"
        }
        if domain == "select" || domain == "input_select" {
            return state
        }
        return state.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    public var sfSymbolName: String {
        let symbolActive = (domain == "lock") ? (state.lowercased() != "locked") : isActive
        return IconMapper.sfSymbol(for: icon, domain: domain, isActive: symbolActive)
    }
}
