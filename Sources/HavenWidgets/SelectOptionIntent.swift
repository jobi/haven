import AppIntents
import Foundation
import NativeHACore
import WidgetKit

/// Interactive AppIntent that selects an option or activity on a multi-choice
/// Home Assistant entity (`remote`, `select`, `input_select`) directly from a widget.
struct SelectOptionIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Option"
    static var description = IntentDescription("Selects an option or activity for a multi-choice Home Assistant entity.")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Entity ID")
    var entityId: String
    
    @Parameter(title: "Option")
    var option: String
    
    @Parameter(title: "Server ID")
    var serverId: String?
    
    init() {
        self.entityId = ""
        self.option = ""
        self.serverId = nil
    }
    
    init(entityId: String, option: String, serverId: String? = nil) {
        self.entityId = entityId
        self.option = option
        self.serverId = serverId
    }
    
    func perform() async throws -> some IntentResult {
        guard !entityId.isEmpty, !option.isEmpty else { return .result() }
        _ = try? await WidgetDataService.shared.selectOption(
            entityId: entityId,
            option: option,
            serverId: serverId
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
