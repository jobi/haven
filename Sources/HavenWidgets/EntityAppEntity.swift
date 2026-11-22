import AppIntents
import Foundation
import NativeHACore

/// Represents a selectable Home Assistant entity in WidgetKit configuration sheets
/// (iOS Home Screen, Lock Screen, StandBy, CarPlay widgets, and HomeView).
/// Encodes `serverId::entityId` in `id` so entities across multiple servers never collide
/// and remain pinned to their chosen server even if the user switches servers in Haven.
struct EntityAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Home Entity"
    static var defaultQuery = EntityAppEntityQuery()
    
    var id: String
    var entityId: String
    var serverId: String?
    var name: String
    var domain: String
    var icon: String?
    
    var displayRepresentation: DisplayRepresentation {
        let symbol = IconMapper.sfSymbol(for: icon, domain: domain, isActive: true)
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(domain.replacingOccurrences(of: "_", with: " ").capitalized) • \(entityId)",
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
    
    init(entityId: String, serverId: String? = nil, name: String, domain: String, icon: String? = nil) {
        self.id = Self.makeCompositeId(serverId: serverId, entityId: entityId)
        self.entityId = entityId
        self.serverId = serverId
        self.name = name
        self.domain = domain
        self.icon = icon
    }
    
    init(snapshot: WidgetEntitySnapshot) {
        self.id = Self.makeCompositeId(serverId: snapshot.serverId, entityId: snapshot.entityId)
        self.entityId = snapshot.entityId
        self.serverId = snapshot.serverId
        self.name = snapshot.friendlyName
        self.domain = snapshot.domain
        self.icon = snapshot.icon
    }
}

struct EntityAppEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [EntityAppEntity] {
        var results: [EntityAppEntity] = []
        var cacheByServer: [String: [String: WidgetEntitySnapshot]] = [:]
        
        for rawId in identifiers {
            let (parsedServerId, entityId) = EntityAppEntity.parseCompositeId(rawId)
            let cacheKey = parsedServerId ?? "__active__"
            
            if cacheByServer[cacheKey] == nil {
                let list = await WidgetDataService.shared.availableEntities(forServerId: parsedServerId)
                cacheByServer[cacheKey] = Dictionary(uniqueKeysWithValues: list.map { ($0.entityId, $0) })
            }
            
            if let snapshot = cacheByServer[cacheKey]?[entityId] {
                results.append(EntityAppEntity(snapshot: snapshot))
            } else {
                let domain = entityId.split(separator: ".").first.map(String.init) ?? "sensor"
                results.append(EntityAppEntity(entityId: entityId, serverId: parsedServerId, name: entityId, domain: domain))
            }
        }
        return results
    }
    
    func entities(matching string: String) async throws -> [EntityAppEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = await WidgetDataService.shared.availableEntities(forServerId: nil)
        if query.isEmpty {
            return all.map(EntityAppEntity.init(snapshot:))
        }
        return all
            .filter {
                $0.friendlyName.lowercased().contains(query) ||
                $0.entityId.lowercased().contains(query) ||
                $0.domain.lowercased().contains(query)
            }
            .map(EntityAppEntity.init(snapshot:))
    }
    
    func suggestedEntities() async throws -> [EntityAppEntity] {
        let all = await WidgetDataService.shared.availableEntities(forServerId: nil)
        return all.map(EntityAppEntity.init(snapshot:))
    }
    
    func defaultResult() async -> EntityAppEntity? {
        let defaults = await WidgetDataService.shared.defaultEntities(forServerId: nil, limit: 1)
        return defaults.first.map(EntityAppEntity.init(snapshot:))
    }
}
