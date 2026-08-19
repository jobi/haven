import SwiftUI

public struct BadgePillView: View {
    let config: AnyCardConfig
    let entityStore: EntityStore
    var onSelect: ((String) -> Void)?
    
    public init(
        config: AnyCardConfig,
        entityStore: EntityStore,
        onSelect: ((String) -> Void)? = nil
    ) {
        self.config = config
        self.entityStore = entityStore
        self.onSelect = onSelect
    }
    
    private var entityId: String? {
        config.rawData["entity"]?.stringValue
    }
    
    private var customIcon: String? {
        config.rawData["icon"]?.stringValue
    }
    
    public var body: some View {
        if let entityId = entityId, let entity = entityStore.entity(for: entityId) {
            Button {
                ActionHandler.handle(
                    actionConfig: config.tapAction,
                    defaultEntityId: entityId,
                    entityStore: entityStore,
                    onMoreInfo: onSelect
                )
            } label: {
                HStack(spacing: 5) {
                    HAIconView(
                        icon: customIcon ?? entity.icon,
                        domain: entity.domain,
                        isActive: entity.isOn
                    )
                    .frame(width: 12, height: 12)
                    .foregroundStyle(iconColor(entity: entity))
                    
                    Text(entity.displayState)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.haCardBackground)
                        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    onSelect?(entityId)
                } label: {
                    Label("More Info", systemImage: "info.circle")
                }
                
                if entity.isToggleable {
                    Button {
                        Task {
                            await entityStore.toggle(entityId: entityId)
                        }
                    } label: {
                        Label(entity.isOn ? "Turn Off" : "Turn On", systemImage: "power")
                    }
                }
            }
            .fixedSize()
        }
    }
    
    private func iconColor(entity: HAEntityState) -> Color {
        guard entity.isOn else { return .secondary }
        switch entity.domain {
        case "light": return .haLightActive
        case "switch", "input_boolean": return .haSwitchActive
        case "climate": return .haClimateHeating
        default: return .haBlue
        }
    }
}
