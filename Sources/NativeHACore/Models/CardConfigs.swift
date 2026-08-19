import Foundation

// MARK: - Tap Actions
public struct ActionConfig: Codable, Sendable, Hashable {
    public let action: String?             // "toggle", "more-info", "call-service", "perform-action", "navigate", "url", "none", "default"
    public let service: String?            // e.g. "light.turn_on"
    public let performAction: String?      // Home Assistant 2024+ synonym
    public let target: [String: AnyCodable]?
    public let data: [String: AnyCodable]?
    public let serviceData: [String: AnyCodable]?
    public let navigationPath: String?
    public let urlPath: String?
    
    public init(
        action: String? = nil,
        service: String? = nil,
        performAction: String? = nil,
        target: [String: AnyCodable]? = nil,
        data: [String: AnyCodable]? = nil,
        serviceData: [String: AnyCodable]? = nil,
        navigationPath: String? = nil,
        urlPath: String? = nil
    ) {
        self.action = action
        self.service = service
        self.performAction = performAction
        self.target = target
        self.data = data
        self.serviceData = serviceData
        self.navigationPath = navigationPath
        self.urlPath = urlPath
    }
    
    enum CodingKeys: String, CodingKey {
        case action, service, target, data
        case performAction = "perform_action"
        case serviceData = "service_data"
        case navigationPath = "navigation_path"
        case urlPath = "url_path"
    }
}

// MARK: - Heading Card Config
public struct HeadingCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let heading: String?
    public let title: String?
    public let headingStyle: String?       // "title", "subtitle", "headline"
    public let icon: String?
    public let badges: [AnyCardConfig]?
    
    public var displayText: String {
        heading ?? title ?? ""
    }
    
    enum CodingKeys: String, CodingKey {
        case type, heading, title, icon, badges
        case headingStyle = "heading_style"
    }
    
    public init(
        type: String = "heading",
        heading: String? = nil,
        title: String? = nil,
        headingStyle: String? = nil,
        icon: String? = nil,
        badges: [AnyCardConfig]? = nil
    ) {
        self.type = type
        self.heading = heading
        self.title = title
        self.headingStyle = headingStyle
        self.icon = icon
        self.badges = badges
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? container.decode(String.self, forKey: .type)) ?? "heading"
        self.heading = try? container.decode(String.self, forKey: .heading)
        self.title = try? container.decode(String.self, forKey: .title)
        self.headingStyle = try? container.decode(String.self, forKey: .headingStyle)
        self.icon = try? container.decode(String.self, forKey: .icon)
        self.badges = try? container.decode([AnyCardConfig].self, forKey: .badges)
    }
}

// MARK: - Tile Card Config
public struct TileCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let entity: String
    public let name: String?
    public let icon: String?
    public let color: String?
    public let tapAction: ActionConfig?
    public let iconTapAction: ActionConfig?
    public let features: [TileFeatureConfig]?
    public let stateContent: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type, entity, name, icon, color, features
        case tapAction = "tap_action"
        case iconTapAction = "icon_tap_action"
        case stateContent = "state_content"
    }
}

// MARK: - Tile Feature Config
public struct TileFeatureConfig: Codable, Sendable, Hashable {
    public let type: String                // "light-brightness", "light-color-temp", "fan-speed", "cover-open-close", "cover-tilt", "cover-position", "target-temperature", "alarm-modes", "vacuum-commands"
    public let style: String?              // "slider", "icons"
    public let modes: [String]?
    public let commands: [String]?
    
    public init(
        type: String,
        style: String? = nil,
        modes: [String]? = nil,
        commands: [String]? = nil
    ) {
        self.type = type
        self.style = style
        self.modes = modes
        self.commands = commands
    }
}

// MARK: - Button Card Config
public struct ButtonCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let entity: String?
    public let name: String?
    public let icon: String?
    public let color: String?
    public let showName: Bool?
    public let showState: Bool?
    public let showIcon: Bool?
    public let tapAction: ActionConfig?
    
    enum CodingKeys: String, CodingKey {
        case type, entity, name, icon, color
        case showName = "show_name"
        case showState = "show_state"
        case showIcon = "show_icon"
        case tapAction = "tap_action"
    }
}

// MARK: - Entities Card Config
public struct EntitiesCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let title: String?
    public let icon: String?
    public let entities: [EntityRowConfig]
    
    public init(type: String = "entities", title: String? = nil, icon: String? = nil, entities: [EntityRowConfig] = []) {
        self.type = type
        self.title = title
        self.icon = icon
        self.entities = entities
    }
}

public struct EntityRowConfig: Codable, Identifiable, Sendable, Hashable {
    public var id: String { entity ?? UUID().uuidString }
    public let entity: String?
    public let name: String?
    public let icon: String?
    public let type: String?               // e.g. "section", "divider", "attribute"
    
    public init(entity: String?, name: String? = nil, icon: String? = nil, type: String? = nil) {
        self.entity = entity
        self.name = name
        self.icon = icon
        self.type = type
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(), let entityId = try? container.decode(String.self) {
            self.entity = entityId
            self.name = nil
            self.icon = nil
            self.type = nil
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.entity = try container.decodeIfPresent(String.self, forKey: .entity)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
            self.type = try container.decodeIfPresent(String.self, forKey: .type)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case entity, name, icon, type
    }
}

// MARK: - Media Control Card Config
public struct MediaControlCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let entity: String
    public let name: String?
    public let icon: String?
    public let tapAction: ActionConfig?
    
    enum CodingKeys: String, CodingKey {
        case type, entity, name, icon
        case tapAction = "tap_action"
    }
    
    public init(
        type: String = "media-control",
        entity: String,
        name: String? = nil,
        icon: String? = nil,
        tapAction: ActionConfig? = nil
    ) {
        self.type = type
        self.entity = entity
        self.name = name
        self.icon = icon
        self.tapAction = tapAction
    }
}

// MARK: - Sensor & Gauge Card Configs
public struct SensorCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let entity: String
    public let name: String?
    public let icon: String?
    public let graph: String?
    public let hoursToShow: Int?
    
    enum CodingKeys: String, CodingKey {
        case type, entity, name, icon, graph
        case hoursToShow = "hours_to_show"
    }
}

public struct GaugeCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let entity: String
    public let name: String?
    public let unit: String?
    public let min: Double?
    public let max: Double?
    public let severity: [String: Double]? // "green": 20, "yellow": 25, "red": 30
    public let needle: Bool?
}

// MARK: - Markdown Card Config
public struct MarkdownCardConfig: Codable, Sendable, Hashable {
    public let type: String
    public let title: String?
    public let content: String
}

// MARK: - Badge Card Config
public struct BadgeCardConfig: Codable, Sendable, Hashable {
    public let type: String?               // "entity"
    public let entity: String?
    public let name: String?
    public let icon: String?
    public let color: String?
    public let tapAction: ActionConfig?
    
    enum CodingKeys: String, CodingKey {
        case type, entity, name, icon, color
        case tapAction = "tap_action"
    }
}
