import SwiftUI

public struct SensorCardView: View {
    let config: SensorCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    public init(
        config: SensorCardConfig?,
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
    
    public var body: some View {
        Button {
            if let entityId = config?.entity {
                onMoreInfo?(entityId)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Top Header: Icon + Name
                HStack(spacing: 8) {
                    HAIconView(
                        icon: config?.icon ?? entity?.icon,
                        domain: entity?.domain
                    )
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
                    
                    Text(config?.name ?? entity?.friendlyName ?? "Sensor")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                // Measurement Value
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(entity?.state ?? "--")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    
                    if let unit = entity?.unitOfMeasurement {
                        Text(unit)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(14)
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
}
