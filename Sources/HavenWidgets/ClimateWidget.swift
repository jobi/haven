import AppIntents
import NativeHACore
import SwiftUI
import WidgetKit

// MARK: - Searchable Climate Entity Picker

struct ClimateEntityAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Thermostat"
    static var defaultQuery = ClimateEntityQuery()
    
    var id: String
    var entityId: String
    var serverId: String?
    var serverName: String?
    var name: String
    var icon: String?
    
    var displayRepresentation: DisplayRepresentation {
        let symbol = IconMapper.sfSymbol(for: icon, domain: "climate", isActive: true)
        let subtitleText: String
        if let serverName, !serverName.isEmpty {
            subtitleText = "\(serverName) • \(entityId)"
        } else {
            subtitleText = entityId
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(subtitleText)",
            image: .init(systemName: symbol)
        )
    }
    
    init(
        entityId: String,
        serverId: String? = nil,
        serverName: String? = nil,
        name: String,
        icon: String? = nil
    ) {
        self.id = EntityAppEntity.makeCompositeId(serverId: serverId, entityId: entityId)
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.name = name
        self.icon = icon
    }
    
    init(snapshot: WidgetEntitySnapshot, serverName: String? = nil) {
        self.id = EntityAppEntity.makeCompositeId(serverId: snapshot.serverId, entityId: snapshot.entityId)
        self.entityId = snapshot.entityId
        self.serverId = snapshot.serverId
        self.serverName = serverName
        self.name = snapshot.friendlyName
        self.icon = snapshot.icon
    }
}

struct ClimateEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ClimateEntityAppEntity] {
        let allGrouped = await WidgetDataService.shared.allServersClimateEntities()
        let serverNames = Dictionary(uniqueKeysWithValues: allGrouped.map { ($0.server.id, $0.server.name) })
        let hasMultiple = allGrouped.count > 1
        
        var mapByServer: [String: [String: WidgetEntitySnapshot]] = [:]
        for group in allGrouped {
            mapByServer[group.server.id] = Dictionary(uniqueKeysWithValues: group.entities.map { ($0.entityId, $0) })
        }
        
        var results: [ClimateEntityAppEntity] = []
        for rawId in identifiers {
            let (parsedServerId, entityId) = EntityAppEntity.parseCompositeId(rawId)
            if let serverId = parsedServerId, let snapshot = mapByServer[serverId]?[entityId] {
                results.append(ClimateEntityAppEntity(
                    snapshot: snapshot,
                    serverName: hasMultiple ? serverNames[serverId] : nil
                ))
            } else {
                results.append(ClimateEntityAppEntity(
                    entityId: entityId,
                    serverId: parsedServerId,
                    serverName: hasMultiple ? parsedServerId.flatMap { serverNames[$0] } : nil,
                    name: entityId
                ))
            }
        }
        return results
    }
    
    func entities(matching string: String) async throws -> IntentItemCollection<ClimateEntityAppEntity> {
        let tokens = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        
        let allGrouped = await WidgetDataService.shared.allServersClimateEntities()
        if tokens.isEmpty {
            return buildSections(from: allGrouped)
        }
        
        let filtered: [(server: ServerConfig, entities: [WidgetEntitySnapshot])] = allGrouped.compactMap { group in
            let serverLower = group.server.name.lowercased()
            let matching = group.entities.filter { snapshot in
                let searchable = "\(snapshot.friendlyName.lowercased()) \(snapshot.entityId.lowercased()) \(serverLower)"
                return tokens.allSatisfy { searchable.contains($0) }
            }
            return matching.isEmpty ? nil : (server: group.server, entities: matching)
        }
        return buildSections(from: filtered)
    }
    
    func suggestedEntities() async throws -> IntentItemCollection<ClimateEntityAppEntity> {
        let allGrouped = await WidgetDataService.shared.allServersClimateEntities()
        return buildSections(from: allGrouped)
    }
    
    func defaultResult() async -> ClimateEntityAppEntity? {
        let allGrouped = await WidgetDataService.shared.allServersClimateEntities()
        let hasMultiple = allGrouped.count > 1
        if let firstGroup = allGrouped.first, let first = firstGroup.entities.first {
            return ClimateEntityAppEntity(snapshot: first, serverName: hasMultiple ? firstGroup.server.name : nil)
        }
        return nil
    }
    
    private func buildSections(
        from grouped: [(server: ServerConfig, entities: [WidgetEntitySnapshot])]
    ) -> IntentItemCollection<ClimateEntityAppEntity> {
        if grouped.count > 1 {
            let sections = grouped.map { group in
                let items = group.entities.map { ClimateEntityAppEntity(snapshot: $0, serverName: group.server.name) }
                return IntentItemSection(LocalizedStringResource(stringLiteral: group.server.name), items: items)
            }
            return IntentItemCollection(sections: sections)
        }
        guard let only = grouped.first else {
            return IntentItemCollection(sections: [])
        }
        let items = only.entities.map { ClimateEntityAppEntity(snapshot: $0) }
        return IntentItemCollection(sections: [IntentItemSection("Thermostats", items: items)])
    }
}

// MARK: - Climate Widget Configuration & Timeline

struct ClimateWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Thermostat"
    static var description = IntentDescription("Choose a Home Assistant climate entity to monitor and control.")
    
    @Parameter(title: "Thermostat")
    var entity: ClimateEntityAppEntity?
}

struct ClimateEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetEntitySnapshot
    let isPlaceholder: Bool
}

struct ClimateProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClimateEntry {
        ClimateEntry(
            date: Date(),
            snapshot: WidgetEntitySnapshot(
                entityId: "climate.living_room",
                friendlyName: "Living Room",
                domain: "climate",
                state: "heat",
                icon: "mdi:thermostat",
                currentTemperature: 71.5,
                targetTemperature: 72.0,
                hvacAction: "heating",
                hvacModes: ["off", "heat", "cool", "heat_cool"],
                temperatureStep: 1.0
            ),
            isPlaceholder: true
        )
    }
    
    func snapshot(for configuration: ClimateWidgetIntent, in context: Context) async -> ClimateEntry {
        let snapshot = await resolveSnapshot(for: configuration)
        return ClimateEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
    }
    
    func timeline(for configuration: ClimateWidgetIntent, in context: Context) async -> Timeline<ClimateEntry> {
        let snapshot = await resolveSnapshot(for: configuration)
        let entry = ClimateEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
    
    private func resolveSnapshot(for configuration: ClimateWidgetIntent) async -> WidgetEntitySnapshot {
        if let entity = configuration.entity,
           let fetched = await WidgetDataService.shared.fetchSnapshot(for: entity.entityId, serverId: entity.serverId) {
            return fetched
        }
        
        let allClimates = await WidgetDataService.shared.allServersClimateEntities()
        if let first = allClimates.flatMap(\.entities).first {
            if let live = await WidgetDataService.shared.fetchSnapshot(for: first.entityId, serverId: first.serverId) {
                return live
            }
            return first
        }
        
        return WidgetEntitySnapshot(
            entityId: "climate.unconfigured",
            friendlyName: "Thermostat",
            domain: "climate",
            state: "off",
            icon: "mdi:thermostat",
            hvacModes: ["off", "heat", "cool", "auto"]
        )
    }
}

// MARK: - Climate Widget View

struct ClimateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClimateEntry
    
    private var snapshot: WidgetEntitySnapshot { entry.snapshot }
    
    private var hvacColor: Color {
        let action = snapshot.hvacAction?.lowercased() ?? ""
        let mode = snapshot.state.lowercased()
        if action == "heating" || (action.isEmpty && mode == "heat") {
            return .orange
        }
        if action == "cooling" || (action.isEmpty && mode == "cool") {
            return .cyan
        }
        if mode == "heat_cool" || mode == "auto" {
            return .teal
        }
        if mode == "heat" {
            return .orange
        }
        if mode == "cool" {
            return .cyan
        }
        return .secondary
    }
    
    private var statusText: String {
        let mode = snapshot.state.lowercased()
        if mode == "off" { return "Off" }
        if let action = snapshot.hvacAction, !action.isEmpty {
            return action.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return formatModeLabel(mode)
    }
    
    private var formattedCurrentTemp: String {
        guard let temp = snapshot.currentTemperature else { return "--" }
        return formatTemp(temp)
    }
    
    private var formattedTargetTemp: String? {
        if let target = snapshot.targetTemperature {
            return formatTemp(target)
        }
        if let low = snapshot.targetTempLow, let high = snapshot.targetTempHigh {
            return "\(formatTemp(low))–\(formatTemp(high))"
        }
        return nil
    }
    
    private var availableModes: [String] {
        let raw = snapshot.hvacModes ?? ["off", "heat", "cool", "auto"]
        return Array(raw.prefix(4))
    }
    
    private var step: Double {
        snapshot.effectiveTemperatureStep
    }
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                Color(.systemBackground)
                if snapshot.state.lowercased() != "off" {
                    LinearGradient(
                        colors: [hvacColor.opacity(0.16), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .widgetURL(WidgetPalette.deepLinkURL(for: snapshot))
    }
    
    // MARK: - Small Layout
    
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(snapshot.friendlyName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: modeSymbol(for: snapshot.state))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(hvacColor)
                    .widgetAccentable()
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(formattedCurrentTemp)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 4) {
                    Text(statusText)
                        .foregroundStyle(hvacColor)
                    if let target = formattedTargetTemp, snapshot.state.lowercased() != "off" {
                        Text("• \(target)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            HStack(spacing: 8) {
                stepperButton(delta: -step, symbol: "minus", compact: true)
                stepperButton(delta: step, symbol: "plus", compact: true)
            }
        }
        .padding(13)
    }
    
    // MARK: - Medium Layout
    
    private var mediumView: some View {
        HStack(spacing: 14) {
            // Left: Temperature readout & +/- stepper
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: modeSymbol(for: snapshot.state))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hvacColor)
                        .widgetAccentable()
                    Text(snapshot.friendlyName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedCurrentTemp)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(statusText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(hvacColor)
                        if let target = formattedTargetTemp, snapshot.state.lowercased() != "off" {
                            Text("Set \(target)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 8) {
                    stepperButton(delta: -step, symbol: "minus", compact: false)
                    stepperButton(delta: step, symbol: "plus", compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Interactive HVAC Mode Buttons
            VStack(spacing: 6) {
                ForEach(availableModes, id: \.self) { mode in
                    modeButton(mode: mode, compact: true)
                }
            }
            .frame(width: 112)
        }
        .padding(14)
    }
    
    // MARK: - Large Layout
    
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: modeSymbol(for: snapshot.state))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(hvacColor)
                        .widgetAccentable()
                    Text(snapshot.friendlyName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Text(statusText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(hvacColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(hvacColor.opacity(0.16)))
            }
            
            // Hero Temperature Display + Stepper
            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(formattedCurrentTemp)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    
                    if let target = formattedTargetTemp, snapshot.state.lowercased() != "off" {
                        Text("Target \(target)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Thermostat Off")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 14) {
                    stepperButton(delta: -step, symbol: "minus", compact: false)
                        .frame(height: 44)
                    stepperButton(delta: step, symbol: "plus", compact: false)
                        .frame(height: 44)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            
            // HVAC Mode Grid
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(availableModes, id: \.self) { mode in
                    modeButton(mode: mode, compact: false)
                        .frame(height: 44)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
    
    // MARK: - Controls
    
    private func stepperButton(delta: Double, symbol: String, compact: Bool) -> some View {
        Button(intent: AdjustTemperatureIntent(
            entityId: snapshot.entityId,
            delta: delta,
            serverId: snapshot.serverId
        )) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 14 : 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 30 : 34)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func modeButton(mode: String, compact: Bool) -> some View {
        let isSelected = snapshot.state.caseInsensitiveCompare(mode) == .orderedSame
        let color = modeColor(for: mode)
        
        return Button(intent: SetHVACModeIntent(
            entityId: snapshot.entityId,
            mode: mode,
            serverId: snapshot.serverId
        )) {
            HStack(spacing: 6) {
                Image(systemName: modeSymbol(for: mode))
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : color)
                Text(formatModeLabel(mode))
                    .font(.system(size: compact ? 11 : 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 10 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                    .fill(isSelected ? color : Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Formatting Helpers
    
    private func formatTemp(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(format: "%.0f°", value)
        }
        return String(format: "%.1f°", value)
    }
    
    private func formatModeLabel(_ mode: String) -> String {
        switch mode.lowercased() {
        case "heat_cool": return "Auto"
        case "fan_only": return "Fan"
        default: return mode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    
    private func modeSymbol(for mode: String) -> String {
        switch mode.lowercased() {
        case "heat": return "flame.fill"
        case "cool": return "snowflake"
        case "heat_cool", "auto": return "thermometer.sun.fill"
        case "fan_only": return "fan.fill"
        case "dry": return "drop.fill"
        case "off": return "power"
        default: return "thermometer.medium"
        }
    }
    
    private func modeColor(for mode: String) -> Color {
        switch mode.lowercased() {
        case "heat": return .orange
        case "cool": return .cyan
        case "heat_cool", "auto": return .teal
        case "fan_only": return .blue
        case "dry": return .indigo
        default: return .secondary
        }
    }
}

struct ClimateWidget: Widget {
    let kind: String = "HavenClimateWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ClimateWidgetIntent.self,
            provider: ClimateProvider()
        ) { entry in
            ClimateWidgetView(entry: entry)
        }
        .configurationDisplayName("Thermostat")
        .description("Monitor temperature, adjust setpoints, and switch HVAC modes for any Home Assistant thermostat.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
