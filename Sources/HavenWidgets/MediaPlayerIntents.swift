import AppIntents
import Foundation
import NativeHACore
import WidgetKit

/// Interactive AppIntent for controlling playback and volume on a Home Assistant `media_player` entity.
struct MediaPlayerCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Control Media Player"
    static var description = IntentDescription("Controls playback or volume on a Home Assistant media player.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Entity ID")
    var entityId: String
    
    @Parameter(title: "Command")
    var command: String
    
    @Parameter(title: "Server ID")
    var serverId: String?
    
    init() {
        self.entityId = ""
        self.command = "play_pause"
        self.serverId = nil
    }
    
    init(entityId: String, command: String, serverId: String? = nil) {
        self.entityId = entityId
        self.command = command
        self.serverId = serverId
    }
    
    func perform() async throws -> some IntentResult {
        guard !entityId.isEmpty else { return .result() }
        _ = try? await WidgetDataService.shared.performMediaCommand(
            entityId: entityId,
            command: command,
            serverId: serverId
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
