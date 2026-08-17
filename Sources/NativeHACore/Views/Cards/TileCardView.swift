import SwiftUI

public struct TileCardView: View {
    let config: TileCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    @State private var localBrightness: Double? = nil
    @State private var isDraggingSlider: Bool = false
    
    public init(
        config: TileCardConfig?,
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
    
    private var displayName: String {
        config?.name ?? entity?.friendlyName ?? config?.entity ?? "Tile"
    }
    
    private var isActive: Bool {
        entity?.isOn == true
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Icon + Name & State
            HStack(spacing: 10) {
                // Circular Icon Badge
                Button {
                    handleTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: IconMapper.sfSymbol(
                            for: config?.icon ?? entity?.icon,
                            domain: entity?.domain,
                            isActive: isActive
                        ))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconForegroundColor)
                    }
                }
                .buttonStyle(.plain)
                
                // Entity Name & State
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text(entity?.displayState ?? "Unknown")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // More Info Button
                if let entityId = config?.entity {
                    Button {
                        onMoreInfo?(entityId)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleTap()
            }
            
            // Features (e.g. Brightness Slider)
            if let features = config?.features, !features.isEmpty, isActive {
                ForEach(features.indices, id: \.self) { idx in
                    let feature = features[idx]
                    if feature.type == "light-brightness" || feature.type == "target-temperature" {
                        brightnessFeatureSlider
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.haCardBackground)
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Feature Slider
    @ViewBuilder
    private var brightnessFeatureSlider: some View {
        let currentBrightness = localBrightness ?? (entity?.brightnessPercentage ?? 50.0)
        
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 28)
                    
                    // Filled Track
                    Capsule()
                        .fill(iconForegroundColor.opacity(0.75))
                        .frame(
                            width: max(28, geo.size.width * CGFloat(currentBrightness / 100.0)),
                            height: 28
                        )
                    
                    // Percentage Label inside bar
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(currentBrightness > 20 ? Color.white : Color.primary.opacity(0.6))
                            .padding(.leading, 8)
                        
                        Spacer()
                        
                        Text("\(Int(currentBrightness))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(currentBrightness > 70 ? Color.white : Color.primary.opacity(0.7))
                            .padding(.trailing, 8)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingSlider = true
                            let pct = max(1.0, min(100.0, Double(value.location.x / geo.size.width) * 100.0))
                            localBrightness = pct
                        }
                        .onEnded { value in
                            let pct = max(1.0, min(100.0, Double(value.location.x / geo.size.width) * 100.0))
                            localBrightness = nil
                            isDraggingSlider = false
                            
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            
                            if let entityId = config?.entity {
                                Task {
                                    await entityStore.setBrightness(entityId: entityId, percentage: pct)
                                }
                            }
                        }
                )
            }
            .frame(height: 28)
        }
    }
    
    // MARK: - Colors & Interactions
    private var iconBackgroundColor: Color {
        if !isActive {
            return Color.primary.opacity(0.06)
        }
        return iconForegroundColor.opacity(0.18)
    }
    
    private var iconForegroundColor: Color {
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
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        
        let action = config?.tapAction?.action ?? "toggle"
        if action == "more-info", let entityId = config?.entity {
            onMoreInfo?(entityId)
        } else if action == "toggle", let entityId = config?.entity {
            Task {
                await entityStore.toggle(entityId: entityId)
            }
        }
    }
}
