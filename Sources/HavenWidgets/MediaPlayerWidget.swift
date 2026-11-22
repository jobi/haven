import AppIntents
import NativeHACore
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Searchable Media Player Entity Picker

struct MediaPlayerEntityAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Media Player"
    static var defaultQuery = MediaPlayerEntityQuery()
    
    var id: String
    var entityId: String
    var serverId: String?
    var serverName: String?
    var name: String
    var icon: String?
    
    var displayRepresentation: DisplayRepresentation {
        let symbol = IconMapper.sfSymbol(for: icon, domain: "media_player", isActive: true)
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

struct MediaPlayerEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [MediaPlayerEntityAppEntity] {
        let allGrouped = await WidgetDataService.shared.allServersMediaPlayerEntities()
        let serverNames = Dictionary(uniqueKeysWithValues: allGrouped.map { ($0.server.id, $0.server.name) })
        let hasMultiple = allGrouped.count > 1
        
        var mapByServer: [String: [String: WidgetEntitySnapshot]] = [:]
        for group in allGrouped {
            mapByServer[group.server.id] = Dictionary(uniqueKeysWithValues: group.entities.map { ($0.entityId, $0) })
        }
        
        var results: [MediaPlayerEntityAppEntity] = []
        for rawId in identifiers {
            let (parsedServerId, entityId) = EntityAppEntity.parseCompositeId(rawId)
            if let serverId = parsedServerId, let snapshot = mapByServer[serverId]?[entityId] {
                results.append(MediaPlayerEntityAppEntity(
                    snapshot: snapshot,
                    serverName: hasMultiple ? serverNames[serverId] : nil
                ))
            } else {
                results.append(MediaPlayerEntityAppEntity(
                    entityId: entityId,
                    serverId: parsedServerId,
                    serverName: hasMultiple ? parsedServerId.flatMap { serverNames[$0] } : nil,
                    name: entityId
                ))
            }
        }
        return results
    }
    
    func entities(matching string: String) async throws -> IntentItemCollection<MediaPlayerEntityAppEntity> {
        let tokens = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        
        let allGrouped = await WidgetDataService.shared.allServersMediaPlayerEntities()
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
    
    func suggestedEntities() async throws -> IntentItemCollection<MediaPlayerEntityAppEntity> {
        let allGrouped = await WidgetDataService.shared.allServersMediaPlayerEntities()
        return buildSections(from: allGrouped)
    }
    
    func defaultResult() async -> MediaPlayerEntityAppEntity? {
        let allGrouped = await WidgetDataService.shared.allServersMediaPlayerEntities()
        let hasMultiple = allGrouped.count > 1
        // Prefer a currently playing media player if one exists
        for group in allGrouped {
            if let playing = group.entities.first(where: { $0.state.lowercased() == "playing" }) {
                return MediaPlayerEntityAppEntity(snapshot: playing, serverName: hasMultiple ? group.server.name : nil)
            }
        }
        if let firstGroup = allGrouped.first, let first = firstGroup.entities.first {
            return MediaPlayerEntityAppEntity(snapshot: first, serverName: hasMultiple ? firstGroup.server.name : nil)
        }
        return nil
    }
    
    private func buildSections(
        from grouped: [(server: ServerConfig, entities: [WidgetEntitySnapshot])]
    ) -> IntentItemCollection<MediaPlayerEntityAppEntity> {
        if grouped.count > 1 {
            let sections = grouped.map { group in
                let items = group.entities.map { MediaPlayerEntityAppEntity(snapshot: $0, serverName: group.server.name) }
                return IntentItemSection(LocalizedStringResource(stringLiteral: group.server.name), items: items)
            }
            return IntentItemCollection(sections: sections)
        }
        guard let only = grouped.first else {
            return IntentItemCollection(sections: [])
        }
        let items = only.entities.map { MediaPlayerEntityAppEntity(snapshot: $0) }
        return IntentItemCollection(sections: [IntentItemSection("Media Players", items: items)])
    }
}

// MARK: - Media Player Widget Configuration & Timeline

struct MediaPlayerWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Media Player"
    static var description = IntentDescription("Choose a Home Assistant media player to monitor and control.")
    
    @Parameter(title: "Media Player")
    var entity: MediaPlayerEntityAppEntity?
}

struct MediaPlayerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetEntitySnapshot
    let artworkData: Data?
    let isPlaceholder: Bool
}

struct MediaPlayerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MediaPlayerEntry {
        MediaPlayerEntry(
            date: Date(),
            snapshot: WidgetEntitySnapshot(
                entityId: "media_player.living_room",
                friendlyName: "Living Room Speaker",
                domain: "media_player",
                state: "playing",
                icon: "mdi:speaker",
                mediaTitle: "Midnight City",
                mediaArtist: "M83",
                volumeLevel: 0.45,
                isVolumeMuted: false
            ),
            artworkData: nil,
            isPlaceholder: true
        )
    }
    
    func snapshot(for configuration: MediaPlayerWidgetIntent, in context: Context) async -> MediaPlayerEntry {
        await buildEntry(for: configuration)
    }
    
    func timeline(for configuration: MediaPlayerWidgetIntent, in context: Context) async -> Timeline<MediaPlayerEntry> {
        let entry = await buildEntry(for: configuration)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
    
    private func buildEntry(for configuration: MediaPlayerWidgetIntent) async -> MediaPlayerEntry {
        let snapshot = await resolveSnapshot(for: configuration)
        let artwork = await WidgetDataService.shared.fetchArtworkData(for: snapshot)
        return MediaPlayerEntry(date: Date(), snapshot: snapshot, artworkData: artwork, isPlaceholder: false)
    }
    
    private func resolveSnapshot(for configuration: MediaPlayerWidgetIntent) async -> WidgetEntitySnapshot {
        if let entity = configuration.entity,
           let fetched = await WidgetDataService.shared.fetchSnapshot(for: entity.entityId, serverId: entity.serverId) {
            return fetched
        }
        
        let allPlayers = await WidgetDataService.shared.allServersMediaPlayerEntities()
        let flat = allPlayers.flatMap(\.entities)
        if let target = flat.first(where: { $0.state.lowercased() == "playing" }) ?? flat.first {
            if let live = await WidgetDataService.shared.fetchSnapshot(for: target.entityId, serverId: target.serverId) {
                return live
            }
            return target
        }
        
        return WidgetEntitySnapshot(
            entityId: "media_player.unconfigured",
            friendlyName: "Media Player",
            domain: "media_player",
            state: "idle",
            icon: "mdi:speaker"
        )
    }
}

// MARK: - Media Player Widget View

struct MediaPlayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MediaPlayerEntry
    
    private var snapshot: WidgetEntitySnapshot { entry.snapshot }
    private var isPlaying: Bool { snapshot.state.lowercased() == "playing" }
    private var isOff: Bool { snapshot.state.lowercased() == "off" || snapshot.state.lowercased() == "standby" }
    private var accent: Color { isPlaying ? .pink : .secondary }
    
    private var artworkImage: UIImage? {
        guard let data = entry.artworkData else { return nil }
        return UIImage(data: data)
    }
    
    private var primaryTitle: String {
        if let title = snapshot.mediaTitle, !title.isEmpty {
            return title
        }
        return snapshot.friendlyName
    }
    
    private var secondarySubtitle: String {
        if let artist = snapshot.mediaArtist, !artist.isEmpty {
            return artist
        }
        if snapshot.mediaTitle != nil {
            return snapshot.friendlyName
        }
        return snapshot.formattedState
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
            if family == .systemSmall, let uiImage = artworkImage {
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    LinearGradient(
                        colors: [.black.opacity(0.35), .black.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                ZStack {
                    Color(.systemBackground)
                    if isPlaying {
                        LinearGradient(
                            colors: [Color.pink.opacity(0.14), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
        }
        .widgetURL(WidgetPalette.deepLinkURL(for: snapshot))
    }
    
    // MARK: - Small Layout
    
    private var smallView: some View {
        let overArt = (artworkImage != nil)
        let primaryColor: Color = overArt ? .white : .primary
        let secondaryColor: Color = overArt ? .white.opacity(0.8) : .secondary
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.sfSymbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(overArt ? .white : accent)
                    .widgetAccentable()
                Text(snapshot.friendlyName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryColor)
                    .lineLimit(2)
                Text(secondarySubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }
            
            HStack(spacing: 8) {
                transportButton(command: "previous", symbol: "backward.fill", size: 13, overArt: overArt)
                transportButton(command: "play_pause", symbol: isPlaying ? "pause.fill" : "play.fill", size: 15, prominent: true, overArt: overArt)
                transportButton(command: "next", symbol: "forward.fill", size: 13, overArt: overArt)
            }
        }
        .padding(13)
    }
    
    // MARK: - Medium Layout
    
    private var mediumView: some View {
        HStack(spacing: 14) {
            artworkThumbnail(size: 118, cornerRadius: 16)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: snapshot.sfSymbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .widgetAccentable()
                    Text(snapshot.friendlyName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(secondarySubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 6) {
                    transportButton(command: "previous", symbol: "backward.fill", size: 13, overArt: false)
                    transportButton(command: "play_pause", symbol: isPlaying ? "pause.fill" : "play.fill", size: 15, prominent: true, overArt: false)
                    transportButton(command: "next", symbol: "forward.fill", size: 13, overArt: false)
                    transportButton(command: "volume_down", symbol: "speaker.wave.1.fill", size: 12, overArt: false)
                    transportButton(command: "volume_up", symbol: "speaker.wave.3.fill", size: 12, overArt: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }
    
    // MARK: - Large Layout
    
    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.sfSymbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                        .widgetAccentable()
                    Text(snapshot.friendlyName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Text(snapshot.formattedState)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isPlaying ? .pink : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((isPlaying ? Color.pink : Color.secondary).opacity(0.14)))
            }
            
            HStack(spacing: 14) {
                artworkThumbnail(size: 116, cornerRadius: 18)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(secondarySubtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Transport Controls
            HStack(spacing: 10) {
                transportButton(command: "previous", symbol: "backward.fill", size: 16, overArt: false)
                    .frame(height: 44)
                transportButton(command: "play_pause", symbol: isPlaying ? "pause.fill" : "play.fill", size: 20, prominent: true, overArt: false)
                    .frame(height: 44)
                transportButton(command: "next", symbol: "forward.fill", size: 16, overArt: false)
                    .frame(height: 44)
            }
            
            // Volume Controls
            HStack(spacing: 10) {
                transportButton(command: "volume_down", symbol: "speaker.wave.1.fill", size: 14, overArt: false)
                    .frame(height: 38)
                
                Button(intent: MediaPlayerCommandIntent(
                    entityId: snapshot.entityId,
                    command: "mute_toggle",
                    serverId: snapshot.serverId
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: (snapshot.isVolumeMuted == true) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                        if let vol = snapshot.volumeLevel {
                            Text("\(Int((vol * 100).rounded()))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        } else {
                            Text((snapshot.isVolumeMuted == true) ? "Muted" : "Mute")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle((snapshot.isVolumeMuted == true) ? .red : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )
                }
                .buttonStyle(.plain)
                
                transportButton(command: "volume_up", symbol: "speaker.wave.3.fill", size: 14, overArt: false)
                    .frame(height: 38)
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func artworkThumbnail(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let uiImage = artworkImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                (isPlaying ? Color.pink : Color.secondary).opacity(0.24),
                                (isPlaying ? Color.purple : Color.secondary).opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: isPlaying ? "music.note" : snapshot.sfSymbolName)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(isPlaying ? .pink : .secondary)
                    .widgetAccentable()
            }
            .frame(width: size, height: size)
        }
    }
    
    private func transportButton(
        command: String,
        symbol: String,
        size: CGFloat,
        prominent: Bool = false,
        overArt: Bool
    ) -> some View {
        Button(intent: MediaPlayerCommandIntent(
            entityId: snapshot.entityId,
            command: command,
            serverId: snapshot.serverId
        )) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(prominent ? .white : (overArt ? .white : .primary))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            prominent
                                ? Color.pink
                                : (overArt ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct MediaPlayerWidget: Widget {
    let kind: String = "HavenMediaPlayerWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MediaPlayerWidgetIntent.self,
            provider: MediaPlayerProvider()
        ) { entry in
            MediaPlayerWidgetView(entry: entry)
        }
        .configurationDisplayName("Media Player")
        .description("See what's playing and control playback and volume for any Home Assistant media player.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
