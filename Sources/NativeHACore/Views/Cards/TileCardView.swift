import SwiftUI

public struct TileCardView: View {
    let config: TileCardConfig?
    let entityStore: EntityStore
    var onMoreInfo: ((String) -> Void)?
    
    @State private var localBrightness: Double? = nil
    @State private var isDraggingSlider: Bool = false
    @State private var localCoverPosition: Double? = nil
    @State private var isDraggingCoverSlider: Bool = false
    
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
    
    private var entityId: String {
        config?.entity ?? ""
    }
    
    private var displayName: String {
        config?.name ?? entity?.friendlyName ?? config?.entity ?? "Tile"
    }
    
    private var isActive: Bool {
        entity?.isOn == true
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Icon Button + Full-Width Name & State (Tap card body for More Info / tapAction)
            HStack(spacing: 10) {
                // Circular Icon Badge Button (Tap toggles entity)
                Button {
                    handleIconTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 38, height: 38)
                        
                        HAIconView(
                            icon: config?.icon ?? entity?.icon,
                            domain: entity?.domain,
                            isActive: isActive
                        )
                        .frame(width: 20, height: 20)
                        .foregroundStyle(iconForegroundColor)
                    }
                }
                .buttonStyle(.plain)
                
                // Entity Name & State (Tap card body for Details)
                VStack(alignment: .leading, spacing: 2) {
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
                .contentShape(Rectangle())
                .onTapGesture {
                    handleCardTap()
                }
            }
            
            // Selectable Options (e.g. Select, Input Select, Harmony Remote Activity)
            if let options = availableOptions, !options.isEmpty {
                optionSelectorFeature(options: options)
            }
            
            // Features (e.g. Blinds Open/Close, Brightness Slider, etc.)
            if let features = config?.features, !features.isEmpty {
                ForEach(features.indices, id: \.self) { idx in
                    let feature = features[idx]
                    renderFeature(feature: feature)
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
        .contextMenu {
            if let entityId = config?.entity {
                Button {
                    onMoreInfo?(entityId)
                } label: {
                    Label("More Info", systemImage: "info.circle")
                }
                
                if entity?.isToggleable == true {
                    Button {
                        Task {
                            await entityStore.toggle(entityId: entityId)
                        }
                    } label: {
                        Label(isActive ? "Turn Off" : "Turn On", systemImage: "power")
                    }
                }
            }
        }
    }
    
    // MARK: - Feature Dispatcher
    @ViewBuilder
    private func renderFeature(feature: TileFeatureConfig) -> some View {
        switch feature.type {
        case "cover-open-close":
            coverOpenCloseFeature
            
        case "cover-position":
            coverPositionFeature
            
        case "cover-tilt":
            coverTiltFeature
            
        case "light-brightness":
            brightnessFeatureSlider
            
        case "fan-speed":
            fanSpeedFeature
            
        case "target-temperature":
            targetTemperatureFeature
            
        case "vacuum-commands":
            vacuumCommandsFeature
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - 1. Cover Open / Close / Stop Feature
    @ViewBuilder
    private var coverOpenCloseFeature: some View {
        HStack(spacing: 4) {
            // Open Button
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                Task {
                    await entityStore.openCover(entityId: entityId)
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Stop Button
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                Task {
                    await entityStore.stopCover(entityId: entityId)
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            // Close Button
            Button {
                #if os(iOS)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                Task {
                    await entityStore.closeCover(entityId: entityId)
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
    
    // MARK: - 2. Cover Position Slider
    @ViewBuilder
    private var coverPositionFeature: some View {
        let currentPos = localCoverPosition ?? (entity?.attributes["current_position"]?.doubleValue ?? 0.0)
        
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 28)
                    
                    Capsule()
                        .fill(iconForegroundColor.opacity(0.75))
                        .frame(
                            width: max(28, geo.size.width * CGFloat(currentPos / 100.0)),
                            height: 28
                        )
                    
                    HStack {
                        Image(systemName: "curtains.closed")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(currentPos > 20 ? Color.white : Color.primary.opacity(0.6))
                            .padding(.leading, 8)
                        
                        Spacer()
                        
                        Text("\(Int(currentPos))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(currentPos > 70 ? Color.white : Color.primary.opacity(0.7))
                            .padding(.trailing, 8)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingCoverSlider = true
                            let pct = max(0.0, min(100.0, Double(value.location.x / geo.size.width) * 100.0))
                            localCoverPosition = pct
                        }
                        .onEnded { value in
                            let pct = max(0.0, min(100.0, Double(value.location.x / geo.size.width) * 100.0))
                            localCoverPosition = nil
                            isDraggingCoverSlider = false
                            
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            
                            Task {
                                await entityStore.setCoverPosition(entityId: entityId, position: Int(pct))
                            }
                        }
                )
            }
            .frame(height: 28)
        }
        .padding(.top, 2)
    }
    
    // MARK: - 3. Cover Tilt Buttons
    @ViewBuilder
    private var coverTiltFeature: some View {
        HStack(spacing: 4) {
            Button {
                Task {
                    await entityStore.callService(domain: "cover", service: "open_cover_tilt", target: ["entity_id": AnyCodable(entityId)])
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.turn.right.up")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button {
                Task {
                    await entityStore.stopCover(entityId: entityId)
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button {
                Task {
                    await entityStore.callService(domain: "cover", service: "close_cover_tilt", target: ["entity_id": AnyCodable(entityId)])
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "arrow.turn.right.down")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
    
    // MARK: - 4. Light Brightness Slider
    @ViewBuilder
    private var brightnessFeatureSlider: some View {
        let isLightOn = entity?.isOn == true
        let currentBrightness = localBrightness ?? (isLightOn ? (entity?.brightnessPercentage ?? 100.0) : 0.0)
        let hasFill = isDraggingSlider || (isLightOn && currentBrightness > 0)
        
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 28)
                    
                    if hasFill {
                        Capsule()
                            .fill(iconForegroundColor.opacity(0.75))
                            .frame(
                                width: max(28, geo.size.width * CGFloat(currentBrightness / 100.0)),
                                height: 28
                            )
                    }
                    
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(hasFill && currentBrightness > 20 ? Color.white : Color.primary.opacity(0.4))
                            .padding(.leading, 8)
                        
                        Spacer()
                        
                        Text(isLightOn || isDraggingSlider ? "\(Int(currentBrightness))%" : "0%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(hasFill && currentBrightness > 70 ? Color.white : Color.primary.opacity(0.5))
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
                            
                            Task {
                                await entityStore.setBrightness(entityId: entityId, percentage: pct)
                            }
                        }
                )
            }
            .frame(height: 28)
        }
        .padding(.top, 2)
    }
    
    // MARK: - 5. Fan Speed Feature
    @ViewBuilder
    private var fanSpeedFeature: some View {
        let currentPct = entity?.attributes["percentage"]?.doubleValue ?? 0.0
        
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 28)
                    
                    Capsule()
                        .fill(Color.haBlue)
                        .frame(
                            width: max(28, geo.size.width * CGFloat(currentPct / 100.0)),
                            height: 28
                        )
                    
                    HStack {
                        Image(systemName: "fan.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(currentPct > 20 ? Color.white : Color.primary.opacity(0.6))
                            .padding(.leading, 8)
                        
                        Spacer()
                        
                        Text("\(Int(currentPct))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(currentPct > 70 ? Color.white : Color.primary.opacity(0.7))
                            .padding(.trailing, 8)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let pct = max(0.0, min(100.0, Double(value.location.x / geo.size.width) * 100.0))
                            Task {
                                await entityStore.callService(
                                    domain: "fan",
                                    service: "set_percentage",
                                    target: ["entity_id": AnyCodable(entityId)],
                                    serviceData: ["percentage": AnyCodable(Int(pct))]
                                )
                            }
                        }
                )
            }
            .frame(height: 28)
        }
        .padding(.top, 2)
    }
    
    // MARK: - 6. Target Temperature Stepper
    @ViewBuilder
    private var targetTemperatureFeature: some View {
        let temp = entity?.attributes["temperature"]?.doubleValue ?? 21.0
        HStack {
            Button {
                Task {
                    await entityStore.setTargetTemperature(entityId: entityId, temperature: temp - 0.5)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(String(format: "%.1f°", temp))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.haClimateHeating)
            
            Spacer()
            
            Button {
                Task {
                    await entityStore.setTargetTemperature(entityId: entityId, temperature: temp + 0.5)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
        .padding(.top, 2)
    }
    
    // MARK: - 7. Vacuum Commands Feature
    @ViewBuilder
    private var vacuumCommandsFeature: some View {
        HStack(spacing: 4) {
            Button {
                Task {
                    await entityStore.callService(domain: "vacuum", service: "start", target: ["entity_id": AnyCodable(entityId)])
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button {
                Task {
                    await entityStore.callService(domain: "vacuum", service: "pause", target: ["entity_id": AnyCodable(entityId)])
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            
            Button {
                Task {
                    await entityStore.callService(domain: "vacuum", service: "return_to_base", target: ["entity_id": AnyCodable(entityId)])
                }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "house.fill")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
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
    
    /// Tapping the circular icon badge toggles the entity
    private func handleIconTap() {
        if let iconAction = config?.iconTapAction {
            ActionHandler.handle(
                actionConfig: iconAction,
                defaultEntityId: config?.entity,
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
        } else if let entityId = config?.entity {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            Task {
                await entityStore.toggle(entityId: entityId)
            }
        }
    }
    
    /// Tapping the card body opens details / more-info (or custom tap_action if configured)
    private func handleCardTap() {
        if let tapAction = config?.tapAction {
            ActionHandler.handle(
                actionConfig: tapAction,
                defaultEntityId: config?.entity,
                entityStore: entityStore,
                onMoreInfo: onMoreInfo
            )
        } else if let entityId = config?.entity {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onMoreInfo?(entityId)
        }
    }
    
    // MARK: - Options Picker Feature
    private var availableOptions: [String]? {
        entity?.attributes["options"]?.arrayValue?.compactMap(\.stringValue) ??
        entity?.attributes["activity_list"]?.arrayValue?.compactMap(\.stringValue)
    }
    
    private var currentOption: String {
        if entity?.domain == "remote" {
            return entity?.attributes["current_activity"]?.stringValue ?? entity?.state ?? "Off"
        }
        return entity?.state ?? availableOptions?.first ?? ""
    }
    
    @ViewBuilder
    private func optionSelectorFeature(options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button {
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    Task {
                        if entity?.domain == "remote" {
                            await entityStore.selectRemoteActivity(entityId: entityId, activity: opt)
                        } else {
                            await entityStore.selectOption(entityId: entityId, option: opt)
                        }
                    }
                } label: {
                    HStack {
                        Text(opt)
                        if opt == currentOption {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(currentOption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
