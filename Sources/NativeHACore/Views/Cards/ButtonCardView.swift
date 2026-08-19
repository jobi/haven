import SwiftUI

public struct ButtonCardView: View {
    let config: ButtonCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    public init(
        config: ButtonCardConfig?,
        entityStore: EntityStore,
        onMoreInfo: ((String) -> Void)? = nil
    ) {
        self.config = config
        self.entityStore = entityStore
        self.onMoreInfo = onMoreInfo
    }
    
    private var entity: HAEntityState? {
        guard let id = config?.entity else { return nil }
        return entityStore.entity(for: id)
    }
    
    private var isActive: Bool {
        entity?.isOn == true
    }
    
    private var displayName: String {
        config?.name ?? entity?.friendlyName ?? config?.entity ?? "Button"
    }
    
    public var body: some View {
        Button {
            handleTap()
        } label: {
            VStack(spacing: 8) {
                if config?.showIcon != false {
                    HAIconView(
                        icon: config?.icon ?? entity?.icon,
                        domain: entity?.domain,
                        isActive: isActive
                    )
                    .frame(width: 32, height: 32)
                    .foregroundStyle(iconColor)
                }
                
                if config?.showName != false {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                if config?.showState == true, let displayState = entity?.displayState {
                    Text(displayState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.haCardBackground)
                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        guard isActive else { return .secondary }
        if let customColor = config?.color {
            return Color(hex: customColor)
        }
        switch entity?.domain {
        case "light": return .haLightActive
        case "switch", "input_boolean": return .haSwitchActive
        case "climate": return .haClimateHeating
        default: return .haBlue
        }
    }
    
    private func handleTap() {
        ActionHandler.handle(
            actionConfig: config?.tapAction,
            defaultEntityId: config?.entity,
            entityStore: entityStore,
            onMoreInfo: onMoreInfo
        )
    }
}
