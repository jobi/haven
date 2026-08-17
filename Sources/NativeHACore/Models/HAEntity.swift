import Foundation

public struct HAEntityState: Identifiable, Sendable, Hashable {
    public let entityId: String
    public var id: String { entityId }
    public let state: String
    public let attributes: [String: AnyCodable]
    public let lastChanged: Date?
    public let lastUpdated: Date?
    
    public init(
        entityId: String,
        state: String,
        attributes: [String: AnyCodable] = [:],
        lastChanged: Date? = nil,
        lastUpdated: Date? = nil
    ) {
        self.entityId = entityId
        self.state = state
        self.attributes = attributes
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Domain & Hierarchy
    public var domain: String {
        entityId.components(separatedBy: ".").first ?? ""
    }
    
    public var name: String {
        entityId.components(separatedBy: ".").dropFirst().joined(separator: ".")
    }
    
    public var friendlyName: String {
        attributes["friendly_name"]?.stringValue ?? entityId
    }
    
    public var icon: String? {
        attributes["icon"]?.stringValue
    }
    
    public var unitOfMeasurement: String? {
        attributes["unit_of_measurement"]?.stringValue
    }
    
    public var deviceClass: String? {
        attributes["device_class"]?.stringValue
    }
    
    // MARK: - State Logic
    public var isUnavailable: Bool {
        state == "unavailable" || state == "unknown"
    }
    
    public var isOn: Bool {
        guard !isUnavailable else { return false }
        switch domain {
        case "light", "switch", "input_boolean", "fan", "automation", "group":
            return state.lowercased() == "on"
        case "binary_sensor":
            return state.lowercased() == "on"
        case "cover":
            return state.lowercased() == "open" || state.lowercased() == "opening"
        case "lock":
            return state.lowercased() == "unlocked"
        case "person", "device_tracker":
            return state.lowercased() == "home"
        case "climate":
            return state.lowercased() != "off" && !isUnavailable
        case "media_player":
            return state.lowercased() == "playing" || state.lowercased() == "paused" || state.lowercased() == "on"
        default:
            return state.lowercased() == "on" || state.lowercased() == "active"
        }
    }
    
    // MARK: - Attribute Helpers
    public var brightness: Double? {
        attributes["brightness"]?.doubleValue
    }
    
    public var brightnessPercentage: Double? {
        guard let b = brightness else { return nil }
        return min(100.0, max(0.0, (b / 255.0) * 100.0))
    }
    
    public var currentTemperature: Double? {
        attributes["current_temperature"]?.doubleValue ?? attributes["temperature"]?.doubleValue
    }
    
    public var targetTemperature: Double? {
        attributes["temperature"]?.doubleValue
    }
    
    public var displayState: String {
        if isUnavailable {
            return "Unavailable"
        }
        
        if let unit = unitOfMeasurement {
            if let d = Double(state) {
                return String(format: "%.1f %@", d, unit)
            }
            return "\(state) \(unit)"
        }
        
        // Capitalize first letter of standard states
        return state.prefix(1).uppercased() + state.dropFirst()
    }
}
