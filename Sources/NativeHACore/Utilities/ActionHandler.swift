import SwiftUI

/// Unified interaction and action execution engine for Home Assistant cards, badges, and chips.
@MainActor
public struct ActionHandler {
    
    /// Executes a configured or default tap/hold/double-tap action.
    public static func handle(
        actionConfig: ActionConfig?,
        defaultEntityId: String?,
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil,
        onNavigate: ((String) -> Void)? = nil
    ) {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        let actionType = actionConfig?.action?.lowercased() ?? "default"
        let targetEntityId = actionConfig?.target?["entity_id"]?.stringValue ?? defaultEntityId
        
        switch actionType {
        case "none":
            return
            
        case "more-info":
            if let entityId = targetEntityId {
                onMoreInfo?(entityId)
            }
            
        case "toggle":
            if let entityId = targetEntityId {
                Task {
                    await entityStore.toggle(entityId: entityId)
                }
            }
            
        case "call-service", "perform-action":
            let serviceStr = actionConfig?.service ?? actionConfig?.performAction
            if let serviceStr = serviceStr, !serviceStr.isEmpty {
                let parts = serviceStr.split(separator: ".", maxSplits: 1)
                let domain = parts.count > 0 ? String(parts[0]) : "homeassistant"
                let service = parts.count > 1 ? String(parts[1]) : "turn_on"
                
                var target = actionConfig?.target
                if target == nil, let entityId = defaultEntityId {
                    target = ["entity_id": AnyCodable(entityId)]
                }
                let data = actionConfig?.data ?? actionConfig?.serviceData
                
                Task {
                    await entityStore.callService(
                        domain: domain,
                        service: service,
                        target: target,
                        serviceData: data
                    )
                }
            } else if let entityId = targetEntityId {
                Task {
                    await entityStore.toggle(entityId: entityId)
                }
            }
            
        case "url":
            if let urlString = actionConfig?.urlPath, let url = URL(string: urlString) {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
            
        case "navigate":
            if let path = actionConfig?.navigationPath {
                onNavigate?(path)
            }
            
        case "default", "":
            // Default behavior based on entity domain:
            guard let entityId = defaultEntityId else { return }
            let domain = entityId.components(separatedBy: ".").first?.lowercased() ?? ""
            
            // Toggleable domains default to toggle
            let toggleableDomains: Set<String> = [
                "input_boolean", "switch", "light", "lock", "fan", "cover", "automation"
            ]
            
            if toggleableDomains.contains(domain) {
                Task {
                    await entityStore.toggle(entityId: entityId)
                }
            } else {
                onMoreInfo?(entityId)
            }
            
        default:
            // Fallback for unknown action string
            if let entityId = targetEntityId {
                let domain = entityId.components(separatedBy: ".").first?.lowercased() ?? ""
                if ["input_boolean", "switch", "light", "lock"].contains(domain) {
                    Task {
                        await entityStore.toggle(entityId: entityId)
                    }
                } else {
                    onMoreInfo?(entityId)
                }
            }
        }
    }
}
