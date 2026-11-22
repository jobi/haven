import AppIntents
import NativeHACore
import SwiftUI
import WidgetKit

struct ControlGridEntityOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<ControlGridWidgetIntent>(\.$server)
    var intent
    
    func results() async throws -> [EntityAppEntity] {
        let serverId = intent?.server.id
        let snapshots = await WidgetDataService.shared.availableEntities(forServerId: serverId)
        return snapshots.map(EntityAppEntity.init(snapshot:))
    }
}

struct ControlGridWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Quick Controls"
    static var description = IntentDescription("Choose a Home Assistant server and up to 6 entities for your interactive control grid.")
    
    @Parameter(title: "Title", default: "Home Controls")
    var title: String
    
    @Parameter(title: "Server")
    var server: ServerAppEntity?
    
    @Parameter(title: "Entity 1", optionsProvider: ControlGridEntityOptionsProvider())
    var entity1: EntityAppEntity?
    
    @Parameter(title: "Entity 2", optionsProvider: ControlGridEntityOptionsProvider())
    var entity2: EntityAppEntity?
    
    @Parameter(title: "Entity 3", optionsProvider: ControlGridEntityOptionsProvider())
    var entity3: EntityAppEntity?
    
    @Parameter(title: "Entity 4", optionsProvider: ControlGridEntityOptionsProvider())
    var entity4: EntityAppEntity?
    
    @Parameter(title: "Entity 5", optionsProvider: ControlGridEntityOptionsProvider())
    var entity5: EntityAppEntity?
    
    @Parameter(title: "Entity 6", optionsProvider: ControlGridEntityOptionsProvider())
    var entity6: EntityAppEntity?
    
    var configuredEntities: [EntityAppEntity] {
        [entity1, entity2, entity3, entity4, entity5, entity6].compactMap { $0 }
    }
}

struct ControlGridEntry: TimelineEntry {
    let date: Date
    let title: String
    let serverName: String?
    let snapshots: [WidgetEntitySnapshot]
}

struct ControlGridProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ControlGridEntry {
        ControlGridEntry(
            date: Date(),
            title: "Home Controls",
            serverName: nil,
            snapshots: [
                WidgetEntitySnapshot(entityId: "light.living_room_ceiling", friendlyName: "Living Room", domain: "light", state: "on", icon: "mdi:ceiling-light"),
                WidgetEntitySnapshot(entityId: "light.kitchen_island", friendlyName: "Kitchen", domain: "light", state: "off", icon: "mdi:lightbulb"),
                WidgetEntitySnapshot(entityId: "lock.front_door", friendlyName: "Front Door", domain: "lock", state: "locked", icon: "mdi:lock"),
                WidgetEntitySnapshot(entityId: "sensor.living_room_temperature", friendlyName: "Temperature", domain: "sensor", state: "72.4", icon: "mdi:thermometer", unitOfMeasurement: "°F")
            ]
        )
    }
    
    func snapshot(for configuration: ControlGridWidgetIntent, in context: Context) async -> ControlGridEntry {
        await buildEntry(for: configuration, family: context.family)
    }
    
    func timeline(for configuration: ControlGridWidgetIntent, in context: Context) async -> Timeline<ControlGridEntry> {
        let entry = await buildEntry(for: configuration, family: context.family)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
    
    private func buildEntry(for configuration: ControlGridWidgetIntent, family: WidgetFamily) async -> ControlGridEntry {
        let maxCount = (family == .systemLarge) ? 6 : 4
        let configured = Array(configuration.configuredEntities.prefix(maxCount))
        let pinnedServerId = configuration.server?.id ?? configured.first?.serverId
        
        let snapshots: [WidgetEntitySnapshot]
        if !configured.isEmpty {
            let entityIds = configured.map(\.entityId)
            let fetched = await WidgetDataService.shared.fetchSnapshots(for: entityIds, serverId: pinnedServerId)
            if !fetched.isEmpty {
                snapshots = fetched
            } else {
                snapshots = await WidgetDataService.shared.defaultEntities(forServerId: pinnedServerId, limit: maxCount)
            }
        } else {
            snapshots = await WidgetDataService.shared.defaultEntities(forServerId: pinnedServerId, limit: maxCount)
        }
        
        let displayTitle = configuration.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedServer = await WidgetDataService.shared.resolveServer(for: pinnedServerId)
        return ControlGridEntry(
            date: Date(),
            title: displayTitle.isEmpty ? (resolvedServer?.name ?? "Home Controls") : displayTitle,
            serverName: resolvedServer?.name,
            snapshots: snapshots
        )
    }
}

struct ControlGridWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ControlGridEntry
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var body: some View {
        let isLarge = (family == .systemLarge)
        let displayed = Array(entry.snapshots.prefix(isLarge ? 6 : 4))
        
        VStack(alignment: .leading, spacing: 8) {
            if isLarge {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                        .widgetAccentable()
                    Text(entry.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.serverName ?? "Haven")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
            }
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(displayed) { snapshot in
                    WidgetEntityTile(snapshot: snapshot, compact: !isLarge)
                        .frame(minHeight: isLarge ? 76 : 56)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct ControlGridWidget: Widget {
    let kind: String = "HavenControlGridWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ControlGridWidgetIntent.self,
            provider: ControlGridProvider()
        ) { entry in
            ControlGridWidgetView(entry: entry)
        }
        .configurationDisplayName("Home Controls Grid")
        .description("Interactive Home Assistant control grid for HomeView, iPad, and Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
