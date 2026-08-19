import Foundation

// MARK: - Dashboard Summary
public struct LovelaceDashboardSummary: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let urlPath: String?
    public let title: String?
    public let icon: String?
    public let showInSidebar: Bool?
    public let requireAdmin: Bool?
    public let mode: String?
    
    public init(
        id: String,
        urlPath: String? = nil,
        title: String? = nil,
        icon: String? = nil,
        showInSidebar: Bool? = true,
        requireAdmin: Bool? = false,
        mode: String? = "storage"
    ) {
        self.id = id
        self.urlPath = urlPath
        self.title = title
        self.icon = icon
        self.showInSidebar = showInSidebar
        self.requireAdmin = requireAdmin
        self.mode = mode
    }
    
    public var displayName: String {
        title ?? (urlPath?.capitalized ?? id.capitalized)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, icon, mode
        case urlPath = "url_path"
        case showInSidebar = "show_in_sidebar"
        case requireAdmin = "require_admin"
    }
}

// MARK: - Full Lovelace Configuration
public struct LovelaceConfig: Codable, Sendable {
    public let title: String?
    public let views: [LovelaceView]
    
    public init(title: String? = nil, views: [LovelaceView] = []) {
        self.title = title
        self.views = views
    }
}

// MARK: - Lovelace View
public struct LovelaceView: Codable, Identifiable, Sendable, Hashable {
    public var id: String { path ?? title ?? UUID().uuidString }
    public let title: String?
    public let path: String?
    public let icon: String?
    public let type: String?             // e.g. "sections", "masonry", "sidebar"
    public let maxColumns: Int?          // Custom column count clamp (default: 4)
    public let badges: [AnyCardConfig]?  // Top-level badge pill configurations
    public let sections: [LovelaceSection]?
    
    public init(
        title: String? = nil,
        path: String? = nil,
        icon: String? = nil,
        type: String? = "sections",
        maxColumns: Int? = nil,
        badges: [AnyCardConfig]? = nil,
        sections: [LovelaceSection]? = nil
    ) {
        self.title = title
        self.path = path
        self.icon = icon
        self.type = type
        self.maxColumns = maxColumns
        self.badges = badges
        self.sections = sections
    }
    
    public var isSectionsType: Bool {
        type == "sections"
    }
    
    public var displayName: String {
        title ?? (path?.capitalized ?? "Overview")
    }
    
    enum CodingKeys: String, CodingKey {
        case title, path, icon, type, badges, sections
        case maxColumns = "max_columns"
    }
}

// MARK: - Lovelace Section
public struct LovelaceSection: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String?
    public let icon: String?
    public let columnSpan: Int?
    public let visibility: [AnyCodable]?
    public let cards: [AnyCardConfig]
    
    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        icon: String? = nil,
        columnSpan: Int? = 1,
        visibility: [AnyCodable]? = nil,
        cards: [AnyCardConfig] = []
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.columnSpan = columnSpan
        self.visibility = visibility
        self.cards = cards
    }
    
    enum CodingKeys: String, CodingKey {
        case title, name, icon, cards, visibility
        case columnSpan = "column_span"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.title = (try? container.decode(String.self, forKey: .title)) ?? (try? container.decode(String.self, forKey: .name))
        self.icon = try container.decodeIfPresent(String.self, forKey: .icon)
        self.columnSpan = try container.decodeIfPresent(Int.self, forKey: .columnSpan)
        self.visibility = try container.decodeIfPresent([AnyCodable].self, forKey: .visibility)
        self.cards = try container.decodeIfPresent([AnyCardConfig].self, forKey: .cards) ?? []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(columnSpan, forKey: .columnSpan)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encode(cards, forKey: .cards)
    }
}

// MARK: - Dynamic Polymorphic Card Config
public struct AnyCardConfig: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let type: String
    public let rawData: [String: AnyCodable]
    
    public init(id: String = UUID().uuidString, type: String, rawData: [String: AnyCodable] = [:]) {
        self.id = id
        self.type = type
        self.rawData = rawData
    }
    
    public init(from decoder: Decoder) throws {
        if let singleStr = try? decoder.singleValueContainer().decode(String.self) {
            self.id = singleStr
            self.type = "badge"
            self.rawData = [
                "type": AnyCodable("badge"),
                "entity": AnyCodable(singleStr)
            ]
            return
        }
        
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.rawData = dict
        self.type = dict["type"]?.stringValue ?? "unknown"
        self.id = dict["id"]?.stringValue ?? UUID().uuidString
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawData)
    }
    
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(rawData)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    public var visibility: [AnyCodable]? {
        rawData["visibility"]?.arrayValue
    }
    
    public var tapAction: ActionConfig? {
        if let tap = rawData["tap_action"] {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(tap),
               let action = try? JSONDecoder().decode(ActionConfig.self, from: encoded) {
                return action
            }
        }
        return nil
    }
    
    public var holdAction: ActionConfig? {
        if let hold = rawData["hold_action"] {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(hold),
               let action = try? JSONDecoder().decode(ActionConfig.self, from: encoded) {
                return action
            }
        }
        return nil
    }
    
    public var doubleTapAction: ActionConfig? {
        if let doubleTap = rawData["double_tap_action"] {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(doubleTap),
               let action = try? JSONDecoder().decode(ActionConfig.self, from: encoded) {
                return action
            }
        }
        return nil
    }
    
    public var gridOptions: CardGridOptions? {
        guard let gridData = rawData["grid_options"] else { return nil }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(gridData),
           let options = try? JSONDecoder().decode(CardGridOptions.self, from: encoded) {
                return options
            }
        return nil
    }
    
    public var columnSpan: Int {
        // 1. Explicit grid_options.columns
        if let explicitCols = gridOptions?.columns {
            return explicitCols >= 2 ? 2 : 1
        }
        
        // 2. Direct dictionary lookup for grid_options.columns
        if let gridDict = rawData["grid_options"]?.dictionaryValue {
            if let cols = gridDict["columns"]?.intValue {
                return cols >= 2 ? 2 : 1
            }
            if let colsStr = gridDict["columns"]?.stringValue, colsStr == "full" {
                return 2
            }
        }
        
        // 3. Defaults based on standard card type conventions in Home Assistant Sections
        switch type {
        case "heading", "markdown", "entities", "media-control", "weather", "map", "picture", "picture-entity", "iframe", "glance", "history-graph", "statistics-graph":
            return 2
        case "tile", "button", "sensor", "gauge", "badge":
            return 1
        default:
            return 2
        }
    }
}

// MARK: - Card Grid Options
public struct CardGridOptions: Codable, Sendable, Hashable {
    public let columns: Int?
    public let rows: Int?
    public let minColumns: Int?
    public let minRows: Int?
    public let maxColumns: Int?
    public let maxRows: Int?
    
    enum CodingKeys: String, CodingKey {
        case columns, rows
        case minColumns = "min_columns"
        case minRows = "min_rows"
        case maxColumns = "max_columns"
        case maxRows = "max_rows"
    }
}
