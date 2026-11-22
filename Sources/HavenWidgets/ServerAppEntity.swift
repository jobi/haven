import AppIntents
import Foundation
import NativeHACore

/// Represents a configured Home Assistant server in WidgetKit configuration sheets.
struct ServerAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Home Assistant Server"
    static var defaultQuery = ServerAppEntityQuery()
    
    var id: String
    var name: String
    var hostDescription: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(hostDescription)",
            image: .init(systemName: "server.rack")
        )
    }
    
    init(id: String, name: String, hostDescription: String) {
        self.id = id
        self.name = name
        self.hostDescription = hostDescription
    }
    
    init(config: ServerConfig) {
        self.id = config.id
        self.name = config.name
        self.hostDescription = config.isDemo ? "Built-in Demo" : (config.url.host ?? config.url.absoluteString)
    }
}

struct ServerAppEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ServerAppEntity] {
        let servers = await WidgetDataService.shared.availableServers()
        let map = Dictionary(uniqueKeysWithValues: servers.map { ($0.id, $0) })
        return identifiers.compactMap { id in
            if let server = map[id] {
                return ServerAppEntity(config: server)
            }
            return nil
        }
    }
    
    func suggestedEntities() async throws -> [ServerAppEntity] {
        let servers = await WidgetDataService.shared.availableServers()
        return servers.map(ServerAppEntity.init(config:))
    }
    
    func defaultResult() async -> ServerAppEntity? {
        if let active = await WidgetDataService.shared.activeServer() {
            return ServerAppEntity(config: active)
        }
        let servers = await WidgetDataService.shared.availableServers()
        return servers.first.map(ServerAppEntity.init(config:))
    }
}
