import AppIntents
import NativeHACore
import SwiftUI
import WidgetKit

// MARK: - Searchable Multi-Choice Entity Picker (Remotes, Select, Input Select)

struct MultiChoiceEntityAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Multi-Choice Entity"
    static var defaultQuery = MultiChoiceEntityQuery()
    
    var id: String
    var entityId: String
    var serverId: String?
    var serverName: String?
    var name: String
    var domain: String
    var icon: String?
    var optionCount: Int
    
    var displayRepresentation: DisplayRepresentation {
        let symbol = IconMapper.sfSymbol(for: icon, domain: domain, isActive: true)
        let domainLabel = domain.replacingOccurrences(of: "_", with: " ").capitalized
        let optionsLabel = optionCount > 0 ? "\(optionCount) options" : domainLabel
        let subtitleText: String
        if let serverName, !serverName.isEmpty {
            subtitleText = "\(serverName) • \(optionsLabel) • \(entityId)"
        } else {
            subtitleText = "\(optionsLabel) • \(entityId)"
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
        domain: String,
        icon: String? = nil,
        optionCount: Int = 0
    ) {
        self.id = EntityAppEntity.makeCompositeId(serverId: serverId, entityId: entityId)
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.name = name
        self.domain = domain
        self.icon = icon
        self.optionCount = optionCount
    }
    
    init(snapshot: WidgetEntitySnapshot, serverName: String? = nil) {
        self.id = EntityAppEntity.makeCompositeId(serverId: snapshot.serverId, entityId: snapshot.entityId)
        self.entityId = snapshot.entityId
        self.serverId = snapshot.serverId
        self.serverName = serverName
        self.name = snapshot.friendlyName
        self.domain = snapshot.domain
        self.icon = snapshot.icon
        self.optionCount = snapshot.options?.count ?? 0
    }
}

struct MultiChoiceEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [MultiChoiceEntityAppEntity] {
        let allGrouped = await WidgetDataService.shared.allServersMultiChoiceEntities()
        let serverNames = Dictionary(uniqueKeysWithValues: allGrouped.map { ($0.server.id, $0.server.name) })
        let hasMultipleServers = allGrouped.count > 1
        
        var mapByServer: [String: [String: WidgetEntitySnapshot]] = [:]
        for group in allGrouped {
            mapByServer[group.server.id] = Dictionary(uniqueKeysWithValues: group.entities.map { ($0.entityId, $0) })
        }
        
        var results: [MultiChoiceEntityAppEntity] = []
        for rawId in identifiers {
            let (parsedServerId, entityId) = EntityAppEntity.parseCompositeId(rawId)
            if let serverId = parsedServerId, let snapshot = mapByServer[serverId]?[entityId] {
                results.append(MultiChoiceEntityAppEntity(
                    snapshot: snapshot,
                    serverName: hasMultipleServers ? serverNames[serverId] : nil
                ))
            } else {
                let domain = entityId.split(separator: ".").first.map(String.init) ?? "remote"
                results.append(MultiChoiceEntityAppEntity(
                    entityId: entityId,
                    serverId: parsedServerId,
                    serverName: hasMultipleServers ? parsedServerId.flatMap { serverNames[$0] } : nil,
                    name: entityId,
                    domain: domain
                ))
            }
        }
        return results
    }
    
    func entities(matching string: String) async throws -> IntentItemCollection<MultiChoiceEntityAppEntity> {
        let tokens = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        
        let allGrouped = await WidgetDataService.shared.allServersMultiChoiceEntities()
        if tokens.isEmpty {
            return buildSections(from: allGrouped)
        }
        
        let filtered: [(server: ServerConfig, entities: [WidgetEntitySnapshot])] = allGrouped.compactMap { group in
            let serverLower = group.server.name.lowercased()
            let matching = group.entities.filter { snapshot in
                let optionsText = (snapshot.options ?? []).joined(separator: " ").lowercased()
                let searchable = "\(snapshot.friendlyName.lowercased()) \(snapshot.entityId.lowercased()) \(snapshot.domain.lowercased()) \(serverLower) \(optionsText)"
                return tokens.allSatisfy { searchable.contains($0) }
            }
            return matching.isEmpty ? nil : (server: group.server, entities: matching)
        }
        return buildSections(from: filtered)
    }
    
    func suggestedEntities() async throws -> IntentItemCollection<MultiChoiceEntityAppEntity> {
        let allGrouped = await WidgetDataService.shared.allServersMultiChoiceEntities()
        return buildSections(from: allGrouped)
    }
    
    func defaultResult() async -> MultiChoiceEntityAppEntity? {
        let allGrouped = await WidgetDataService.shared.allServersMultiChoiceEntities()
        let hasMultiple = allGrouped.count > 1
        // Prefer a remote entity (e.g. Harmony) first if available
        for group in allGrouped {
            if let remote = group.entities.first(where: { $0.domain == "remote" }) {
                return MultiChoiceEntityAppEntity(snapshot: remote, serverName: hasMultiple ? group.server.name : nil)
            }
        }
        if let firstGroup = allGrouped.first, let first = firstGroup.entities.first {
            return MultiChoiceEntityAppEntity(snapshot: first, serverName: hasMultiple ? firstGroup.server.name : nil)
        }
        return nil
    }
    
    private func buildSections(
        from grouped: [(server: ServerConfig, entities: [WidgetEntitySnapshot])]
    ) -> IntentItemCollection<MultiChoiceEntityAppEntity> {
        if grouped.count > 1 {
            let sections = grouped.map { group in
                let items = group.entities.map { MultiChoiceEntityAppEntity(snapshot: $0, serverName: group.server.name) }
                return IntentItemSection(LocalizedStringResource(stringLiteral: group.server.name), items: items)
            }
            return IntentItemCollection(sections: sections)
        }
        
        guard let only = grouped.first else {
            return IntentItemCollection(sections: [])
        }
        
        var sections: [IntentItemSection<MultiChoiceEntityAppEntity>] = []
        let remotes = only.entities.filter { $0.domain == "remote" }.map { MultiChoiceEntityAppEntity(snapshot: $0) }
        if !remotes.isEmpty {
            sections.append(IntentItemSection("Remotes & Activities", items: remotes))
        }
        let selects = only.entities.filter { $0.domain != "remote" }.map { MultiChoiceEntityAppEntity(snapshot: $0) }
        if !selects.isEmpty {
            sections.append(IntentItemSection("Selectors", items: selects))
        }
        return IntentItemCollection(sections: sections)
    }
}

// MARK: - Option Picker Widget Configuration & Timeline

struct OptionPickerWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Entity"
    static var description = IntentDescription("Choose any multi-choice Home Assistant entity to control from your widget.")
    
    @Parameter(title: "Entity")
    var entity: MultiChoiceEntityAppEntity?
}

struct OptionPickerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetEntitySnapshot
    let isPlaceholder: Bool
}

struct OptionPickerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> OptionPickerEntry {
        OptionPickerEntry(
            date: Date(),
            snapshot: WidgetEntitySnapshot(
                entityId: "select.home_mode",
                friendlyName: "Home Mode",
                domain: "select",
                state: "Home",
                icon: "mdi:form-dropdown",
                options: ["Home", "Away", "Movie", "Sleep"],
                currentOption: "Home"
            ),
            isPlaceholder: true
        )
    }
    
    func snapshot(for configuration: OptionPickerWidgetIntent, in context: Context) async -> OptionPickerEntry {
        let snapshot = await resolveSnapshot(for: configuration)
        return OptionPickerEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
    }
    
    func timeline(for configuration: OptionPickerWidgetIntent, in context: Context) async -> Timeline<OptionPickerEntry> {
        let snapshot = await resolveSnapshot(for: configuration)
        let entry = OptionPickerEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
    
    private func resolveSnapshot(for configuration: OptionPickerWidgetIntent) async -> WidgetEntitySnapshot {
        if let entity = configuration.entity,
           let fetched = await WidgetDataService.shared.fetchSnapshot(for: entity.entityId, serverId: entity.serverId) {
            return fetched
        }
        
        let allMulti = await WidgetDataService.shared.allServersMultiChoiceEntities()
        if let remote = allMulti.flatMap(\.entities).first(where: { $0.domain == "remote" }) {
            if let live = await WidgetDataService.shared.fetchSnapshot(for: remote.entityId, serverId: remote.serverId) {
                return live
            }
            return remote
        }
        if let first = allMulti.flatMap(\.entities).first {
            if let live = await WidgetDataService.shared.fetchSnapshot(for: first.entityId, serverId: first.serverId) {
                return live
            }
            return first
        }
        
        return WidgetEntitySnapshot(
            entityId: "select.unconfigured",
            friendlyName: "Option Picker",
            domain: "select",
            state: "off",
            icon: "mdi:form-dropdown",
            options: [],
            currentOption: nil
        )
    }
}

// MARK: - Widget View

struct OptionPickerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: OptionPickerEntry
    
    private var accent: Color {
        entry.snapshot.domain == "remote" ? .indigo : .blue
    }
    
    private var displayOptions: [String] {
        let raw = entry.snapshot.options ?? []
        // Filter out redundant PowerOff from the grid for remotes since we show a dedicated Power Off button in the header
        if entry.snapshot.domain == "remote" {
            return raw.filter {
                let l = $0.lowercased()
                return l != "poweroff" && l != "power_off"
            }
        }
        return raw
    }
    
    private var maxOptions: Int {
        switch family {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 10
        default: return 4
        }
    }
    
    private var visibleOptions: [String] {
        var opts = Array(displayOptions.prefix(maxOptions))
        // Always ensure the currently active option is visible even if it sits past maxOptions
        if let activeOpt = displayOptions.first(where: { isOptionSelected($0) }),
           !opts.contains(activeOpt),
           !opts.isEmpty {
            opts[opts.count - 1] = activeOpt
        }
        return opts
    }
    
    var body: some View {
        let snapshot = entry.snapshot
        let options = visibleOptions
        
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            // Header: Icon + Name + Power Off button (for remotes)
            HStack(spacing: 6) {
                Image(systemName: snapshot.sfSymbolName)
                    .font(.system(size: family == .systemSmall ? 13 : 15, weight: .semibold))
                    .foregroundStyle(snapshot.isActive ? accent : .secondary)
                    .widgetAccentable()
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.friendlyName)
                        .font(.system(size: family == .systemSmall ? 12 : 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if family != .systemSmall {
                        Text(snapshot.formattedState)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(snapshot.isActive ? accent : .secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                if snapshot.domain == "remote" {
                    Button(intent: SelectOptionIntent(
                        entityId: snapshot.entityId,
                        option: "PowerOff",
                        serverId: snapshot.serverId
                    )) {
                        Image(systemName: snapshot.isActive ? "power.circle.fill" : "power.circle")
                            .font(.system(size: family == .systemSmall ? 20 : 24, weight: .medium))
                            .foregroundStyle(snapshot.isActive ? Color.red : Color.secondary)
                            .widgetAccentable()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            
            // Interactive Option Buttons
            if options.isEmpty {
                Spacer(minLength: 0)
                Text("No options available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            } else if family == .systemSmall {
                VStack(spacing: 5) {
                    ForEach(options, id: \.self) { option in
                        optionButton(option: option, compact: true)
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ]
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        optionButton(option: option, compact: family == .systemMedium)
                            .frame(minHeight: family == .systemLarge ? 48 : 42)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(WidgetPalette.deepLinkURL(for: snapshot))
    }
    
    private func isOptionSelected(_ option: String) -> Bool {
        let snapshot = entry.snapshot
        let current = (snapshot.currentOption ?? snapshot.state)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = option.trimmingCharacters(in: .whitespacesAndNewlines)
        if snapshot.domain == "remote" {
            let lowerCurrent = current.lowercased()
            if lowerCurrent == "poweroff" || lowerCurrent == "power_off" || lowerCurrent == "off" {
                return false
            }
            // If current_activity explicitly matches an activity name, treat it as selected
            // even if remote state hasn't flipped yet.
            return current.caseInsensitiveCompare(candidate) == .orderedSame
        }
        return current.caseInsensitiveCompare(candidate) == .orderedSame
    }
    
    private func optionButton(option: String, compact: Bool) -> some View {
        let selected = isOptionSelected(option)
        return Button(intent: SelectOptionIntent(
            entityId: entry.snapshot.entityId,
            option: option,
            serverId: entry.snapshot.serverId
        )) {
            HStack(spacing: 6) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: compact ? 12 : 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text(option)
                    .font(.system(size: compact ? 11 : 13, weight: selected ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(selected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                    .fill(selected ? accent : Color.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                    .strokeBorder(
                        selected ? accent : Color.primary.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct OptionPickerWidget: Widget {
    let kind: String = "HavenOptionPickerWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: OptionPickerWidgetIntent.self,
            provider: OptionPickerProvider()
        ) { entry in
            OptionPickerWidgetView(entry: entry)
        }
        .configurationDisplayName("Option Picker")
        .description("Quickly switch modes, activities, or options for any multi-choice Home Assistant entity.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
