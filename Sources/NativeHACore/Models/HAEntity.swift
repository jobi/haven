import Foundation

public struct HAEntityState: Identifiable, Sendable, Hashable {
    public let entityId: String
    public var id: String { entityId }
    public var state: String
    public var attributes: [String: AnyCodable]
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
        if let explicit = attributes["icon"]?.stringValue, !explicit.isEmpty {
            return explicit
        }
        return defaultIconForEntity
    }
    
    private var defaultIconForEntity: String {
        let dc = deviceClass?.lowercased() ?? ""
        let unit = unitOfMeasurement?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // 1. Device class mappings
        switch dc {
        case "temperature":
            return "mdi:thermometer"
        case "humidity":
            return "mdi:water-percent"
        case "pressure", "atmospheric_pressure":
            return "mdi:gauge"
        case "battery":
            return "mdi:battery"
        case "power":
            return "mdi:flash"
        case "energy":
            return "mdi:lightning-bolt"
        case "illuminance":
            return "mdi:brightness-5"
        case "motion":
            return "mdi:motion-sensor"
        case "occupancy", "presence":
            return "mdi:home-account"
        case "door", "garage_door":
            return "mdi:door"
        case "window":
            return "mdi:window-closed"
        case "smoke":
            return "mdi:smoke-detector"
        case "gas":
            return "mdi:gas-cylinder"
        case "co", "carbon_monoxide", "co2", "carbon_dioxide":
            return "mdi:molecule-co2"
        case "moisture":
            return "mdi:water"
        case "current":
            return "mdi:current-ac"
        case "voltage":
            return "mdi:sine-wave"
        case "speed", "wind_speed":
            return "mdi:weather-windy"
        case "signal_strength":
            return "mdi:wifi"
        case "sound":
            return "mdi:volume-high"
        case "timestamp", "date":
            return "mdi:clock-outline"
        default:
            break
        }
        
        // 2. Unit of measurement mappings
        switch unit {
        case "°C", "°F", "K", "C", "F":
            return "mdi:thermometer"
        case "%":
            if name.lowercased().contains("battery") {
                return "mdi:battery"
            }
            return "mdi:water-percent"
        case "hPa", "mbar", "bar", "psi", "inHg", "mmHg":
            return "mdi:gauge"
        case "W", "kW", "mW", "VA", "kVA":
            return "mdi:flash"
        case "Wh", "kWh", "MWh":
            return "mdi:lightning-bolt"
        case "lx", "lm":
            return "mdi:brightness-5"
        case "V", "mV":
            return "mdi:sine-wave"
        case "A", "mA":
            return "mdi:current-ac"
        case "km/h", "mph", "m/s", "kn":
            return "mdi:weather-windy"
        case "dB", "dBm":
            return "mdi:wifi"
        default:
            break
        }
        
        // 3. Domain fallbacks
        switch domain {
        case "light": return "mdi:lightbulb"
        case "switch", "input_boolean": return "mdi:toggle-switch"
        case "climate": return "mdi:thermostat"
        case "fan": return "mdi:fan"
        case "cover": return "mdi:curtains"
        case "lock": return "mdi:lock"
        case "media_player": return "mdi:speaker"
        case "camera": return "mdi:cctv"
        case "vacuum": return "mdi:robot-vacuum"
        case "remote": return "mdi:remote"
        case "select", "input_select": return "mdi:form-dropdown"
        case "scene": return "mdi:palette"
        case "script": return "mdi:script-text"
        case "automation": return "mdi:robot"
        case "person", "device_tracker": return "mdi:account"
        case "weather": return "mdi:weather-partly-cloudy"
        case "alarm_control_panel": return "mdi:shield-home"
        case "timer": return "mdi:timer-outline"
        case "sun": return "mdi:weather-sunny"
        default: return "mdi:eye"
        }
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
    
    public var isToggleable: Bool {
        switch domain {
        case "light", "switch", "input_boolean", "fan", "cover", "lock", "automation", "media_player":
            return true
        default:
            return false
        }
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
