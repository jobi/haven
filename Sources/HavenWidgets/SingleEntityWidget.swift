import AppIntents
import NativeHACore
import SwiftUI
import WidgetKit

struct SingleEntityOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<SingleEntityWidgetIntent>(\.$server)
    var intent
    
    func results() async throws -> [EntityAppEntity] {
        let serverId = intent?.server.id
        let snapshots = await WidgetDataService.shared.availableEntities(forServerId: serverId)
        return snapshots.map(EntityAppEntity.init(snapshot:))
    }
    
    func defaultResult() async -> EntityAppEntity? {
        let serverId = intent?.server.id
        let defaults = await WidgetDataService.shared.defaultEntities(forServerId: serverId, limit: 1)
        return defaults.first.map(EntityAppEntity.init(snapshot:))
    }
}

struct SingleEntityWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Home Entity"
    static var description = IntentDescription("Choose a Home Assistant server and entity to display and control.")
    
    @Parameter(title: "Server")
    var server: ServerAppEntity?
    
    @Parameter(title: "Entity", optionsProvider: SingleEntityOptionsProvider())
    var entity: EntityAppEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$server
            \.$entity
        }
    }
}

struct SingleEntityEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetEntitySnapshot
    let isPlaceholder: Bool
}

struct SingleEntityProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SingleEntityEntry {
        SingleEntityEntry(
            date: Date(),
            snapshot: WidgetEntitySnapshot(
                entityId: "light.living_room_ceiling",
                friendlyName: "Living Room",
                domain: "light",
                state: "on",
                icon: "mdi:ceiling-light"
            ),
            isPlaceholder: true
        )
    }
    
    func snapshot(for configuration: SingleEntityWidgetIntent, in context: Context) async -> SingleEntityEntry {
        let snapshot = await resolveSnapshot(for: configuration)
        return SingleEntityEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
    }
    
    func timeline(for configuration: SingleEntityWidgetIntent, in context: Context) async -> Timeline<SingleEntityEntry> {
        let snapshot = await resolveSnapshot(for: configuration)
        let entry = SingleEntityEntry(date: Date(), snapshot: snapshot, isPlaceholder: false)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
    
    private func resolveSnapshot(for configuration: SingleEntityWidgetIntent) async -> WidgetEntitySnapshot {
        let pinnedServerId = configuration.server?.id ?? configuration.entity?.serverId
        
        if let entity = configuration.entity {
            let targetServerId = pinnedServerId ?? entity.serverId
            if let fetched = await WidgetDataService.shared.fetchSnapshot(for: entity.entityId, serverId: targetServerId) {
                return fetched
            }
        }
        
        if let defaultEntity = await WidgetDataService.shared.defaultEntities(forServerId: pinnedServerId, limit: 1).first {
            return defaultEntity
        }
        
        return WidgetEntitySnapshot(
            entityId: "light.living_room_ceiling",
            serverId: pinnedServerId,
            friendlyName: configuration.server?.name ?? "Haven",
            domain: "light",
            state: "off",
            icon: "mdi:home"
        )
    }
}

struct SingleEntityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SingleEntityEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallCardView
        }
    }
    
    private var smallCardView: some View {
        let snapshot = entry.snapshot
        let accent = WidgetPalette.accentColor(for: snapshot)
        let symbol = snapshot.sfSymbolName
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(snapshot.isActive ? accent.opacity(0.22) : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(snapshot.isActive ? accent : .secondary)
                        .widgetAccentable()
                }
                
                Spacer()
                
                if snapshot.isControllable {
                    Button(intent: ToggleEntityIntent(entityId: snapshot.entityId, serverId: snapshot.serverId)) {
                        Image(systemName: snapshot.isActive ? "power.circle.fill" : "power.circle")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(snapshot.isActive ? accent : .secondary)
                            .widgetAccentable()
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.friendlyName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(snapshot.formattedState)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(snapshot.isActive ? accent : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            ZStack {
                Color(.systemBackground)
                if snapshot.isActive {
                    LinearGradient(
                        colors: [accent.opacity(0.18), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .widgetURL(WidgetPalette.deepLinkURL(for: snapshot))
    }
    
    private var circularView: some View {
        let snapshot = entry.snapshot
        let symbol = IconMapper.sfSymbol(
            for: snapshot.icon,
            domain: snapshot.domain,
            isActive: snapshot.isActive
        )
        
        return ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(snapshot.state.prefix(5))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(WidgetPalette.deepLinkURL(for: snapshot))
    }
    
    private var rectangularView: some View {
        let snapshot = entry.snapshot
        let symbol = IconMapper.sfSymbol(
            for: snapshot.icon,
            domain: snapshot.domain,
            isActive: snapshot.isActive
        )
        
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .widgetAccentable()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.friendlyName)
                    .font(.headline)
                    .lineLimit(1)
                Text(snapshot.formattedState)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(WidgetPalette.deepLinkURL(for: snapshot))
    }
}

struct SingleEntityWidget: Widget {
    let kind: String = "HavenSingleEntityWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SingleEntityWidgetIntent.self,
            provider: SingleEntityProvider()
        ) { entry in
            SingleEntityWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Entity")
        .description("Monitor and control a Home Assistant device on HomeView, CarPlay, StandBy, or your Home Screen.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
