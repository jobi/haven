import AppIntents
import Foundation
import NativeHACore

/// Represents a selectable Home Assistant entity in WidgetKit configuration sheets
/// (iOS Home Screen, Lock Screen, StandBy, CarPlay widgets, and HomeView).
/// Encodes `serverId::entityId` in `id` so entities across multiple servers never collide
/// and remain permanently pinned to their server even if the user switches servers in Haven.
struct EntityAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Home Entity"
    static var defaultQuery = EntityAppEntityQuery()
    
    var id: String
    var entityId: String
    var serverId: String?
    var serverName: String?
    var name: String
    var domain: String
    var icon: String?
    
    var displayRepresentation: DisplayRepresentation {
        let symbol = IconMapper.sfSymbol(for: icon, domain: domain, isActive: true)
        let domainLabel = domain.replacingOccurrences(of: "_", with: " ").capitalized
        let subtitleText: String
        if let serverName, !serverName.isEmpty {
            subtitleText = "\(serverName) • \(domainLabel) • \(entityId)"
        } else {
            subtitleText = "\(domainLabel) • \(entityId)"
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(subtitleText)",
            image: .init(systemName: symbol)
        )
    }
    
    static func makeCompositeId(serverId: String?, entityId: String) -> String {
        if let serverId, !serverId.isEmpty {
            return "\(serverId)::\(entityId)"
        }
        return entityId
    }
    
    static func parseCompositeId(_ rawId: String) -> (serverId: String?, entityId: String) {
        if let range = rawId.range(of: "::") {
            let serverId = String(rawId[..<range.lowerBound])
            let entityId = String(rawId[range.upperBound...])
            return (serverId.isEmpty ? nil : serverId, entityId)
        }
        return (nil, rawId)
    }
    
    init(
        entityId: String,
        serverId: String? = nil,
        serverName: String? = nil,
        name: String,
        domain: String,
        icon: String? = nil
    ) {
        self.id = Self.makeCompositeId(serverId: serverId, entityId: entityId)
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.name = name
        self.domain = domain
        self.icon = icon
    }
    
    init(snapshot: WidgetEntitySnapshot, serverName: String? = nil) {
        self.id = Self.makeCompositeId(serverId: snapshot.serverId, entityId: snapshot.entityId)
        self.entityId = snapshot.entityId
        self.serverId = snapshot.serverId
        self.serverName = serverName
        self.name = snapshot.friendlyName
        self.domain = snapshot.domain
        self.icon = snapshot.icon
    }
}

/// Searchable (`EntityStringQuery`) and sectioned (`IntentItemCollection`) query for WidgetKit.
/// Enables the native iOS Search bar at the top of the widget entity picker and organizes
/// entities into Server or Category sections so finding any entity is fast even with hundreds of entities.
struct EntityAppEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [EntityAppEntity] {
        let allGrouped = await WidgetDataService.shared.allServersEntities()
        let serverNames = Dictionary(uniqueKeysWithValues: allGrouped.map { ($0.server.id, $0.server.name) })
        let hasMultipleServers = allGrouped.count > 1
        
        var mapByServer: [String: [String: WidgetEntitySnapshot]] = [:]
        for group in allGrouped {
            mapByServer[group.server.id] = Dictionary(uniqueKeysWithValues: group.entities.map { ($0.entityId, $0) })
        }
        
        var results: [EntityAppEntity] = []
        for rawId in identifiers {
            let (parsedServerId, entityId) = EntityAppEntity.parseCompositeId(rawId)
            if let serverId = parsedServerId, let snapshot = mapByServer[serverId]?[entityId] {
                results.append(EntityAppEntity(
                    snapshot: snapshot,
                    serverName: hasMultipleServers ? serverNames[serverId] : nil
                ))
            } else if let fallback = allGrouped.first?.entities.first(where: { $0.entityId == entityId }) {
                results.append(EntityAppEntity(
                    snapshot: fallback,
                    serverName: hasMultipleServers ? allGrouped.first?.server.name : nil
                ))
            } else {
                let domain = entityId.split(separator: ".").first.map(String.init) ?? "sensor"
                results.append(EntityAppEntity(
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
    
    func entities(matching string: String) async throws -> IntentItemCollection<EntityAppEntity> {
        let tokens = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        
        let allGrouped = await WidgetDataService.shared.allServersEntities()
        if tokens.isEmpty {
            return buildSections(from: allGrouped)
        }
        
        let filteredGrouped: [(server: ServerConfig, entities: [WidgetEntitySnapshot])] = allGrouped.compactMap { group in
            let serverLower = group.server.name.lowercased()
            let matching = group.entities.filter { snapshot in
                let searchable = "\(snapshot.friendlyName.lowercased()) \(snapshot.entityId.lowercased()) \(snapshot.domain.lowercased()) \(serverLower)"
                return tokens.allSatisfy { searchable.contains($0) }
            }
            return matching.isEmpty ? nil : (server: group.server, entities: matching)
        }
        
        return buildSections(from: filteredGrouped)
    }
    
    func suggestedEntities() async throws -> IntentItemCollection<EntityAppEntity> {
        let allGrouped = await WidgetDataService.shared.allServersEntities()
        return buildSections(from: allGrouped)
    }
    
    func defaultResult() async -> EntityAppEntity? {
        let active = await WidgetDataService.shared.activeServer()
        let defaults = await WidgetDataService.shared.defaultEntities(forServerId: active?.id, limit: 1)
        let servers = await WidgetDataService.shared.availableServers()
        return defaults.first.map {
            EntityAppEntity(snapshot: $0, serverName: servers.count > 1 ? active?.name : nil)
        }
    }
    
    // MARK: - Section Grouping
    
    private func buildSections(
        from grouped: [(server: ServerConfig, entities: [WidgetEntitySnapshot])]
    ) -> IntentItemCollection<EntityAppEntity> {
        // Multiple servers: group by Server first (each server's entities sorted by friendlyName)
        if grouped.count > 1 {
            let sections: [IntentItemSection<EntityAppEntity>] = grouped.map { group in
                let items = group.entities.map {
                    EntityAppEntity(snapshot: $0, serverName: group.server.name)
                }
                return IntentItemSection(LocalizedStringResource(stringLiteral: group.server.name), items: items)
            }
            return IntentItemCollection(sections: sections)
        }
        
        // Single server: group by device category (Lights, Switches, Locks & Covers, Climate, etc.)
        guard let only = grouped.first else {
            return IntentItemCollection(sections: [])
        }
        
        let categoryOrder: [(title: String, domains: Set<String>)] = [
            ("Lights", ["light"]),
            ("Switches & Fans", ["switch", "input_boolean", "fan"]),
            ("Locks & Covers", ["lock", "cover"]),
            ("Climate & Weather", ["climate", "weather"]),
            ("Scenes & Scripts", ["scene", "script", "automation"]),
            ("Remotes & Selectors", ["remote", "select", "input_select"]),
            ("Media Players", ["media_player"]),
            ("Sensors", ["sensor", "binary_sensor"])
        ]
        
        var sections: [IntentItemSection<EntityAppEntity>] = []
        var usedIds = Set<String>()
        
        for category in categoryOrder {
            let matching = only.entities
                .filter { category.domains.contains($0.domain) }
                .map { EntityAppEntity(snapshot: $0) }
            if !matching.isEmpty {
                matching.forEach { usedIds.insert($0.id) }
                sections.append(IntentItemSection(LocalizedStringResource(stringLiteral: category.title), items: matching))
            }
        }
        
        let remaining = only.entities
            .map { EntityAppEntity(snapshot: $0) }
            .filter { !usedIds.contains($0.id) }
        if !remaining.isEmpty {
            sections.append(IntentItemSection("Other", items: remaining))
        }
        
        return IntentItemCollection(sections: sections)
    }
}
