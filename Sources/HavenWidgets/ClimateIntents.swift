import AppIntents
import Foundation
import NativeHACore
import WidgetKit

/// Interactive AppIntent that raises or lowers a thermostat's target temperature from a widget.
struct AdjustTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust Thermostat Temperature"
    static var description = IntentDescription("Raises or lowers a Home Assistant thermostat's target temperature.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Entity ID")
    var entityId: String
    
    @Parameter(title: "Delta")
    var delta: Double
    
    @Parameter(title: "Server ID")
    var serverId: String?
    
    init() {
        self.entityId = ""
        self.delta = 1.0
        self.serverId = nil
    }
    
    init(entityId: String, delta: Double, serverId: String? = nil) {
        self.entityId = entityId
        self.delta = delta
        self.serverId = serverId
    }
    
    func perform() async throws -> some IntentResult {
        guard !entityId.isEmpty else { return .result() }
        _ = try? await WidgetDataService.shared.adjustClimateTemperature(
            entityId: entityId,
            delta: delta,
            serverId: serverId
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Interactive AppIntent that switches a thermostat's HVAC mode (`off`, `heat`, `cool`, `heat_cool`, `auto`).
struct SetHVACModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Thermostat Mode"
    static var description = IntentDescription("Changes the HVAC mode of a Home Assistant thermostat.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Entity ID")
    var entityId: String
    
    @Parameter(title: "HVAC Mode")
    var mode: String
    
    @Parameter(title: "Server ID")
    var serverId: String?
    
    init() {
        self.entityId = ""
        self.mode = "off"
        self.serverId = nil
    }
    
    init(entityId: String, mode: String, serverId: String? = nil) {
        self.entityId = entityId
        self.mode = mode
        self.serverId = serverId
    }
    
    func perform() async throws -> some IntentResult {
        guard !entityId.isEmpty, !mode.isEmpty else { return .result() }
        _ = try? await WidgetDataService.shared.setClimateHVACMode(
            entityId: entityId,
            mode: mode,
            serverId: serverId
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
