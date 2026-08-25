import SwiftUI

/// Rich, interactive Home Assistant "More Info" detail sheet supporting all entity domains.
public struct EntityMoreInfoSheet: View {
    public let entityId: String
    public let entityStore: EntityStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var localBrightness: Double = 50.0
    @State private var isDraggingBrightness: Bool = false
    @State private var localColorTemp: Double = 3000.0
    @State private var isDraggingColorTemp: Bool = false
    @State private var localVolume: Double = 0.5
    @State private var isDraggingVolume: Bool = false
    @State private var localTargetTemp: Double = 21.0
    
    @State private var historyPoints: [HistoryDataPoint] = []
    @State private var selectedHistoryHours: Int = 24
    @State private var isLoadingHistory: Bool = false
    
    public init(entityId: String, entityStore: EntityStore) {
        self.entityId = entityId
        self.entityStore = entityStore
    }
    
    private var entity: HAEntityState? {
        entityStore.entity(for: entityId)
    }
    
    private var domain: String {
        entity?.domain ?? entityId.components(separatedBy: ".").first ?? ""
    }
    
    private var displayName: String {
        entity?.friendlyName ?? entityId
    }
    
    private var isActive: Bool {
        entity?.isOn == true
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // MARK: - 1. Hero Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(heroBadgeBackground)
                                .frame(width: 52, height: 52)
                            
                            HAIconView(
                                icon: entity?.icon,
                                domain: domain,
                                isActive: isActive
                            )
                            .frame(width: 26, height: 26)
                            .foregroundStyle(heroBadgeForeground)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                            
                            Text(entityId)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(entity?.displayState ?? "Unknown")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isActive ? heroBadgeForeground : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(heroBadgeBackground)
                            )
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - 2. Domain Controls
                domainControlsSection
                
                // MARK: - 3. Info & Timestamps
                Section("Details") {
                    HStack {
                        Text("Domain")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(domain.capitalized)
                            .font(.subheadline.weight(.medium))
                    }
                    
                    HStack {
                        Text("State")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entity?.state ?? "unknown")
                            .font(.subheadline.monospaced())
                    }
                    
                    if let lastUpdated = entity?.lastUpdated {
                        HStack {
                            Text("Last Updated")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastUpdated, style: .relative)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - 4. Attributes Inspector
                if let attrs = entity?.attributes, !attrs.isEmpty {
                    Section("Attributes") {
                        ForEach(Array(attrs.keys.sorted()), id: \.self) { key in
                            if let val = attrs[key] {
                                HStack(alignment: .top) {
                                    Text(key)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(displayValue(for: val))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                syncLocalState()
                loadHistory()
            }
            .onChange(of: entity?.state) {
                syncLocalState()
                loadHistory()
            }
            .onChange(of: selectedHistoryHours) {
                loadHistory()
            }
        }
    }
    
    private func loadHistory() {
        Task {
            let val = Double(entity?.state ?? "")
            let points = await HistoryService.shared.fetchHistory(
                serverURL: entityStore.isDemoMode ? nil : entityStore.serverURL,
                token: nil,
                entityId: entityId,
                currentValue: val,
                hours: selectedHistoryHours
            )
            await MainActor.run {
                self.historyPoints = points
            }
        }
    }
    
    private func syncLocalState() {
        if entity?.isOn == true {
            localBrightness = entity?.brightnessPercentage ?? 100.0
        } else {
            localBrightness = 0.0
        }
        if let temp = entity?.attributes["temperature"]?.doubleValue ?? entity?.attributes["target_temp_high"]?.doubleValue {
            localTargetTemp = temp
        }
        if let ct = entity?.attributes["color_temp_kelvin"]?.doubleValue {
            localColorTemp = ct
        }
        if let vol = entity?.attributes["volume_level"]?.doubleValue {
            localVolume = vol
        }
    }
    
    // MARK: - Domain Controls Builder
    @ViewBuilder
    private var domainControlsSection: some View {
        switch domain {
        case "light":
            lightControls
            
        case "switch", "input_boolean":
            switchControls
            
        case "climate":
            climateControls
            
        case "media_player":
            mediaPlayerControls
            
        case "cover":
            coverControls
            
        case "lock":
            lockControls
            
        case "fan":
            fanControls
            
        case "automation", "script", "scene":
            actionEntityControls
            
        case "sensor", "binary_sensor":
            sensorControls
            
        case "camera":
            cameraControls
            
        case "select", "input_select", "remote":
            selectControls
            
        default:
            if availableOptions != nil && !(availableOptions?.isEmpty ?? true) {
                selectControls
            } else {
                genericControls
            }
        }
    }
    
    // MARK: - 1. Light Controls
    @ViewBuilder
    private var lightControls: some View {
        Section("Light Controls") {
            // Power Toggle
            Toggle("Power", isOn: Binding(
                get: { isActive },
                set: { _ in
                    Task {
                        await entityStore.toggle(entityId: entityId)
                    }
                }
            ))
            
            // Brightness Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Brightness", systemImage: "sun.max.fill")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(localBrightness))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $localBrightness, in: 1...100, step: 1) {
                    Text("Brightness")
                } onEditingChanged: { isEditing in
                    isDraggingBrightness = isEditing
                    if !isEditing {
                        Task {
                            await entityStore.setBrightness(entityId: entityId, percentage: localBrightness)
                        }
                    }
                }
                .tint(.haLightActive)
            }
            .padding(.vertical, 4)
            
            // Color Temperature Slider (Warm to Cool)
            if supportsColorTemp {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Color Temperature", systemImage: "thermometer.sun.fill")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(localColorTemp)) K")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $localColorTemp, in: 2200...6500, step: 50) {
                        Text("Color Temperature")
                    } onEditingChanged: { isEditing in
                        isDraggingColorTemp = isEditing
                        if !isEditing {
                            Task {
                                await entityStore.setLightColorTemp(entityId: entityId, kelvin: Int(localColorTemp))
                            }
                        }
                    }
                    .tint(.orange)
                }
                .padding(.vertical, 4)
            }
            
            // Color Presets
            if supportsColor {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color Presets")
                        .font(.subheadline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            colorPresetButton(name: "Warm White", r: 255, g: 214, b: 170)
                            colorPresetButton(name: "Soft White", r: 255, g: 241, b: 224)
                            colorPresetButton(name: "Daylight", r: 255, g: 255, b: 255)
                            colorPresetButton(name: "Red", r: 255, g: 59, b: 48)
                            colorPresetButton(name: "Orange", r: 255, g: 149, b: 0)
                            colorPresetButton(name: "Yellow", r: 255, g: 204, b: 0)
                            colorPresetButton(name: "Green", r: 52, g: 199, b: 89)
                            colorPresetButton(name: "Cyan", r: 0, g: 199, b: 190)
                            colorPresetButton(name: "Blue", r: 0, g: 122, b: 255)
                            colorPresetButton(name: "Purple", r: 175, g: 82, b: 222)
                            colorPresetButton(name: "Pink", r: 255, g: 45, b: 85)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Effects List
            if let effects = entity?.attributes["effect_list"]?.arrayValue?.compactMap({ $0.stringValue }), !effects.isEmpty {
                let currentEffect = entity?.attributes["effect"]?.stringValue ?? "None"
                Menu {
                    ForEach(effects, id: \.self) { effect in
                        Button {
                            Task {
                                await entityStore.setLightEffect(entityId: entityId, effect: effect)
                            }
                        } label: {
                            HStack {
                                Text(effect)
                                if effect == currentEffect {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Effect")
                        Spacer()
                        Text(currentEffect)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func colorPresetButton(name: String, r: Int, g: Int, b: Int) -> some View {
        Button {
            Task {
                await entityStore.setLightRGB(entityId: entityId, r: r, g: g, b: b)
            }
        } label: {
            Circle()
                .fill(Color(red: Double(r)/255.0, green: Double(g)/255.0, blue: Double(b)/255.0))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
    
    private var supportsColorTemp: Bool {
        if entity?.attributes["color_temp_kelvin"] != nil || entity?.attributes["color_temp"] != nil {
            return true
        }
        let modes = entity?.attributes["supported_color_modes"]?.arrayValue?.compactMap { $0.stringValue } ?? []
        return modes.contains("color_temp")
    }
    
    private var supportsColor: Bool {
        if entity?.attributes["rgb_color"] != nil || entity?.attributes["hs_color"] != nil {
            return true
        }
        let modes = entity?.attributes["supported_color_modes"]?.arrayValue?.compactMap { $0.stringValue } ?? []
        return modes.contains("rgb") || modes.contains("rgbw") || modes.contains("rgbww") || modes.contains("hs") || modes.contains("xy")
    }
    
    // MARK: - 2. Switch Controls
    @ViewBuilder
    private var switchControls: some View {
        Section("Controls") {
            Toggle("Power", isOn: Binding(
                get: { isActive },
                set: { _ in
                    Task {
                        await entityStore.toggle(entityId: entityId)
                    }
                }
            ))
        }
    }
    
    // MARK: - 3. Climate Controls
    @ViewBuilder
    private var climateControls: some View {
        Section("Thermostat") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Temperature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", entity?.currentTemperature ?? 0.0))
                        .font(.title2.weight(.bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Target Temperature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f°", localTargetTemp))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.haClimateHeating)
                }
            }
            .padding(.vertical, 4)
            
            // Stepper buttons for Target Temp
            HStack(spacing: 20) {
                Button {
                    localTargetTemp -= 0.5
                    Task {
                        await entityStore.setTargetTemperature(entityId: entityId, temperature: localTargetTemp)
                    }
                } label: {
                    Label("Decrease", systemImage: "minus.circle.fill")
                        .font(.title2)
                }
                
                Slider(value: $localTargetTemp, in: 10...32, step: 0.5) {
                    Text("Target Temperature")
                } onEditingChanged: { isEditing in
                    if !isEditing {
                        Task {
                            await entityStore.setTargetTemperature(entityId: entityId, temperature: localTargetTemp)
                        }
                    }
                }
                .tint(.haClimateHeating)
                
                Button {
                    localTargetTemp += 0.5
                    Task {
                        await entityStore.setTargetTemperature(entityId: entityId, temperature: localTargetTemp)
                    }
                } label: {
                    Label("Increase", systemImage: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .labelStyle(.iconOnly)
            
            // HVAC Mode Picker
            if let modes = entity?.attributes["hvac_modes"]?.arrayValue?.compactMap({ $0.stringValue }), !modes.isEmpty {
                let currentMode = entity?.state ?? "off"
                Picker("Operation Mode", selection: Binding(
                    get: { currentMode },
                    set: { newMode in
                        Task {
                            await entityStore.setHVACMode(entityId: entityId, mode: newMode)
                        }
                    }
                )) {
                    ForEach(modes, id: \.self) { mode in
                        Text(mode.capitalized).tag(mode)
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Media Player Controls
    @ViewBuilder
    private var mediaPlayerControls: some View {
        Section("Media Controls") {
            HStack(spacing: 20) {
                Spacer()
                
                Button {
                    Task {
                        await entityStore.mediaPreviousTrack(entityId: entityId)
                    }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button {
                    Task {
                        await entityStore.mediaPlayPause(entityId: entityId)
                    }
                } label: {
                    Image(systemName: entity?.state == "playing" ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.haBlue)
                }
                .buttonStyle(.plain)
                
                Button {
                    Task {
                        await entityStore.mediaNextTrack(entityId: entityId)
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Volume
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Volume", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(localVolume * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $localVolume, in: 0...1, step: 0.01) {
                    Text("Volume")
                } onEditingChanged: { isEditing in
                    isDraggingVolume = isEditing
                    if !isEditing {
                        Task {
                            await entityStore.setVolume(entityId: entityId, level: localVolume)
                        }
                    }
                }
                .tint(.haBlue)
            }
            .padding(.vertical, 4)
            
            Toggle("Power", isOn: Binding(
                get: { isActive },
                set: { _ in
                    Task {
                        await entityStore.toggle(entityId: entityId)
                    }
                }
            ))
        }
    }
    
    // MARK: - 5. Cover Controls
    @ViewBuilder
    private var coverControls: some View {
        Section("Cover Controls") {
            HStack(spacing: 16) {
                Button {
                    Task { await entityStore.openCover(entityId: entityId) }
                } label: {
                    Label("Open", systemImage: "arrow.up.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task { await entityStore.stopCover(entityId: entityId) }
                } label: {
                    Label("Stop", systemImage: "stop.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                
                Button {
                    Task { await entityStore.closeCover(entityId: entityId) }
                } label: {
                    Label("Close", systemImage: "arrow.down.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - 6. Lock Controls
    @ViewBuilder
    private var lockControls: some View {
        Section("Lock Controls") {
            let isLocked = entity?.state.lowercased() == "locked"
            Button {
                Task {
                    await entityStore.setLock(entityId: entityId, lock: !isLocked)
                }
            } label: {
                HStack {
                    Label(isLocked ? "Unlock Door" : "Lock Door", systemImage: isLocked ? "lock.open.fill" : "lock.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - 7. Fan Controls
    @ViewBuilder
    private var fanControls: some View {
        Section("Fan Controls") {
            Toggle("Power", isOn: Binding(
                get: { isActive },
                set: { _ in
                    Task {
                        await entityStore.toggle(entityId: entityId)
                    }
                }
            ))
        }
    }
    
    // MARK: - 8. Action Entity Controls (Automation/Script/Scene)
    @ViewBuilder
    private var actionEntityControls: some View {
        Section("Actions") {
            Button {
                Task {
                    if domain == "automation" {
                        await entityStore.triggerAutomation(entityId: entityId)
                    } else {
                        await entityStore.turnOn(entityId: entityId)
                    }
                }
            } label: {
                HStack {
                    Label("Run Action", systemImage: "play.fill")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - 9. Sensor Controls & History Graph
    @ViewBuilder
    private var sensorControls: some View {
        Section("Sensor Reading") {
            HStack {
                Text("Measurement")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entity?.displayState ?? "--")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 4)
        }
        
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("History", systemImage: "chart.xyaxis.line")
                        .font(.headline)
                    Spacer()
                    Picker("Time Range", selection: $selectedHistoryHours) {
                        Text("6h").tag(6)
                        Text("12h").tag(12)
                        Text("24h").tag(24)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }
                
                SensorHistoryChartView(
                    historyPoints: historyPoints,
                    unit: entity?.unitOfMeasurement,
                    tintColor: heroBadgeForeground
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("History Graph")
        }
    }
    
    // MARK: - 10. Select & Remote Activity Controls
    @ViewBuilder
    private var selectControls: some View {
        if let options = availableOptions, !options.isEmpty {
            Section(domain == "remote" ? "Activity" : "Options") {
                ForEach(options, id: \.self) { opt in
                    Button {
                        #if os(iOS)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        Task {
                            if domain == "remote" {
                                await entityStore.selectRemoteActivity(entityId: entityId, activity: opt)
                            } else {
                                await entityStore.selectOption(entityId: entityId, option: opt)
                            }
                        }
                    } label: {
                        HStack {
                            Text(opt)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if opt == currentSelectedOption {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(heroBadgeForeground)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var availableOptions: [String]? {
        entity?.attributes["options"]?.arrayValue?.compactMap(\.stringValue) ??
        entity?.attributes["activity_list"]?.arrayValue?.compactMap(\.stringValue)
    }
    
    private var currentSelectedOption: String {
        if domain == "remote" {
            return entity?.attributes["current_activity"]?.stringValue ?? entity?.state ?? "Off"
        }
        return entity?.state ?? availableOptions?.first ?? ""
    }
    
    // MARK: - 11. Generic Controls Fallback
    @ViewBuilder
    private var genericControls: some View {
        if entity?.isToggleable == true {
            Section("Controls") {
                Toggle("Power", isOn: Binding(
                    get: { isActive },
                    set: { _ in
                        Task {
                            await entityStore.toggle(entityId: entityId)
                        }
                    }
                ))
            }
        }
    }
    
    // MARK: - 11. Camera Controls
    @ViewBuilder
    private var cameraControls: some View {
        Section {
            HACameraStreamView(
                entityId: entityId,
                entityStore: entityStore,
                entityPicture: entity?.attributes["entity_picture"]?.stringValue
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
        }
        
        Section("Camera Status") {
            if let streamType = entity?.attributes["frontend_stream_type"]?.stringValue {
                HStack {
                    Text("Stream Type")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(streamType.uppercased())
                        .font(.subheadline.monospaced().weight(.semibold))
                }
            }
            
            if let motion = entity?.attributes["motion_detection"]?.boolValue {
                HStack {
                    Text("Motion Detection")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(motion ? "Active" : "Disabled")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(motion ? Color.green : Color.secondary)
                }
            }
            
            if let brand = entity?.attributes["brand"]?.stringValue {
                HStack {
                    Text("Brand")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(brand)
                        .font(.subheadline)
                }
            }
            
            if let model = entity?.attributes["model_name"]?.stringValue {
                HStack {
                    Text("Model")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(model)
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Badges & Colors
    private var heroBadgeBackground: Color {
        if isActive {
            return heroBadgeForeground.opacity(0.15)
        }
        return Color.primary.opacity(0.06)
    }
    
    private var heroBadgeForeground: Color {
        guard isActive else { return .secondary }
        switch domain {
        case "light": return .haLightActive
        case "switch", "input_boolean": return .haSwitchActive
        case "climate": return .haClimateHeating
        default: return .haBlue
        }
    }
    
    private func displayValue(for codable: AnyCodable) -> String {
        if let s = codable.stringValue { return s }
        if let i = codable.intValue { return "\(i)" }
        if let d = codable.doubleValue { return String(format: "%.2f", d) }
        if let b = codable.boolValue { return b ? "true" : "false" }
        if let arr = codable.arrayValue {
            let items = arr.compactMap { $0.stringValue ?? "\($0.value)" }
            return items.joined(separator: ", ")
        }
        if let dict = codable.dictionaryValue { return "{\(dict.count) keys}" }
        return "-"
    }
}
