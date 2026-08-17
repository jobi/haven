import SwiftUI

public struct GaugeCardView: View {
    let config: GaugeCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    public init(
        config: GaugeCardConfig?,
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
    
    private var currentValue: Double {
        guard let stateStr = entity?.state, let val = Double(stateStr) else { return 0 }
        return val
    }
    
    private var minValue: Double {
        config?.min ?? 0.0
    }
    
    private var maxValue: Double {
        config?.max ?? 100.0
    }
    
    public var body: some View {
        Button {
            if let entityId = config?.entity {
                onMoreInfo?(entityId)
            }
        } label: {
            VStack(spacing: 8) {
                // Name
                Text(config?.name ?? entity?.friendlyName ?? "Gauge")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // Native SwiftUI Gauge
                Gauge(value: currentValue, in: minValue...maxValue) {
                    Text(config?.name ?? "Gauge")
                } currentValueLabel: {
                    Text(String(format: "%.1f", currentValue))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                } minimumValueLabel: {
                    Text("\(Int(minValue))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } maximumValueLabel: {
                    Text("\(Int(maxValue))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(gaugeColor)
                .scaleEffect(1.2)
                .padding(.vertical, 8)
                
                // Unit
                if let unit = config?.unit ?? entity?.unitOfMeasurement {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
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
    
    private var gaugeColor: Color {
        guard let severity = config?.severity else {
            return .haBlue
        }
        
        let redThreshold = severity["red"] ?? 80.0
        let yellowThreshold = severity["yellow"] ?? 50.0
        let greenThreshold = severity["green"] ?? 0.0
        
        if currentValue >= redThreshold {
            return .red
        } else if currentValue >= yellowThreshold {
            return .yellow
        } else {
            return .green
        }
    }
}
