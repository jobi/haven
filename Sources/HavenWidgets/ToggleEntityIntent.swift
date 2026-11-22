import AppIntents
import Foundation
import NativeHACore
import WidgetKit

/// Interactive AppIntent allowing users to toggle lights, switches, locks, covers,
/// or trigger scenes/scripts directly from HomeView, CarPlay, StandBy, and Home Screen widgets,
/// scoped to the widget's pinned Home Assistant server.
struct ToggleEntityIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Home Entity"
    static var description = IntentDescription("Toggles a Home Assistant device or triggers a scene/script.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Entity ID")
    var entityId: String
    
    @Parameter(title: "Server ID")
    var serverId: String?
    
    init() {
        self.entityId = ""
        self.serverId = nil
    }
    
    init(entityId: String, serverId: String? = nil) {
        self.entityId = entityId
        self.serverId = serverId
    }
    
    func perform() async throws -> some IntentResult {
        guard !entityId.isEmpty else { return .result() }
        _ = try? await WidgetDataService.shared.toggleEntity(entityId: entityId, serverId: serverId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
