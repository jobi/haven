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
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onSelect?(entityId)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: IconMapper.sfSymbol(
                        for: customIcon ?? entity.icon,
                        domain: entity.domain,
                        isActive: entity.isOn
                    ))
                    .font(.system(size: 11, weight: .semibold))
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
