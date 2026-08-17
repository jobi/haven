import Foundation

public struct IconMapper: Sendable {
    
    /// Resolves an MDI icon name (e.g. "mdi:lightbulb-outline") or entity domain to an Apple SF Symbol name.
    public static func sfSymbol(
        for haIcon: String?,
        domain: String? = nil,
        isActive: Bool = false
    ) -> String {
        if let icon = haIcon, !icon.isEmpty {
            let cleanIcon = icon.hasPrefix("mdi:") ? String(icon.dropFirst(4)) : icon
            if let mapped = mdiToSFSymbolMap[cleanIcon] {
                return isActive ? (mapped.active ?? mapped.normal) : mapped.normal
            }
        }
        
        // Fallback to domain mapping if icon is absent or unmapped
        if let domain = domain {
            return domainFallback(domain: domain, isActive: isActive)
        }
        
        return isActive ? "circle.fill" : "circle"
    }
    
    private struct SymbolPair {
        let normal: String
        let active: String?
    }
    
    private static let mdiToSFSymbolMap: [String: SymbolPair] = [
        // Lights
        "lightbulb": SymbolPair(normal: "lightbulb", active: "lightbulb.fill"),
        "lightbulb-outline": SymbolPair(normal: "lightbulb", active: "lightbulb.fill"),
        "lightbulb-group": SymbolPair(normal: "lightbulb.2", active: "lightbulb.2.fill"),
        "lightbulb-group-outline": SymbolPair(normal: "lightbulb.2", active: "lightbulb.2.fill"),
        "ceiling-light": SymbolPair(normal: "light.recessed", active: "light.recessed.fill"),
        "ceiling-light-outline": SymbolPair(normal: "light.recessed", active: "light.recessed.fill"),
        "wall-sconce": SymbolPair(normal: "light.panel", active: "light.panel.fill"),
        "floor-lamp": SymbolPair(normal: "lamp.floor", active: "lamp.floor.fill"),
        "desk-lamp": SymbolPair(normal: "lamp.desk", active: "lamp.desk.fill"),
        "led-strip": SymbolPair(normal: "light.ribbon", active: "light.ribbon.fill"),
        "outdoor-lamp": SymbolPair(normal: "light.beacon.max", active: "light.beacon.max.fill"),
        
        // Switches & Plugs
        "power": SymbolPair(normal: "power", active: "power.circle.fill"),
        "power-plug": SymbolPair(normal: "powerplug", active: "powerplug.fill"),
        "power-socket-us": SymbolPair(normal: "powerplug", active: "powerplug.fill"),
        "power-socket-eu": SymbolPair(normal: "powerplug", active: "powerplug.fill"),
        "toggle-switch": SymbolPair(normal: "switch.2", active: "switch.2"),
        "toggle-switch-off": SymbolPair(normal: "switch.2", active: "switch.2"),
        "flash": SymbolPair(normal: "bolt", active: "bolt.fill"),
        
        // Climate & Fans
        "thermostat": SymbolPair(normal: "thermometer.medium", active: "thermometer.sun.fill"),
        "thermometer": SymbolPair(normal: "thermometer.medium", active: "thermometer.sun.fill"),
        "fan": SymbolPair(normal: "fan", active: "fan.fill"),
        "fan-speed-1": SymbolPair(normal: "fan", active: "fan.fill"),
        "fan-speed-2": SymbolPair(normal: "fan", active: "fan.fill"),
        "fan-speed-3": SymbolPair(normal: "fan", active: "fan.fill"),
        "air-conditioner": SymbolPair(normal: "air.conditioner.horizontal", active: "air.conditioner.horizontal.fill"),
        "air-purifier": SymbolPair(normal: "air.purifier", active: "air.purifier.fill"),
        "water-percent": SymbolPair(normal: "humidity", active: "humidity.fill"),
        "fire": SymbolPair(normal: "flame", active: "flame.fill"),
        "snowflake": SymbolPair(normal: "snowflake", active: "snowflake"),
        
        // Doors, Windows, Covers & Locks
        "door": SymbolPair(normal: "door.left.hand.closed", active: "door.left.hand.open"),
        "door-closed": SymbolPair(normal: "door.left.hand.closed", active: "door.left.hand.open"),
        "door-open": SymbolPair(normal: "door.left.hand.open", active: "door.left.hand.open"),
        "window-closed": SymbolPair(normal: "window.vertical.closed", active: "window.vertical.open"),
        "window-open": SymbolPair(normal: "window.vertical.open", active: "window.vertical.open"),
        "window-shutter": SymbolPair(normal: "curtains.closed", active: "curtains.open"),
        "curtains": SymbolPair(normal: "curtains.closed", active: "curtains.open"),
        "blinds": SymbolPair(normal: "blinds.vertical.closed", active: "blinds.vertical.open"),
        "garage": SymbolPair(normal: "garage.closed", active: "garage.open"),
        "garage-open": SymbolPair(normal: "garage.open", active: "garage.open"),
        "lock": SymbolPair(normal: "lock.fill", active: "lock.open.fill"),
        "lock-outline": SymbolPair(normal: "lock", active: "lock.open"),
        "lock-open": SymbolPair(normal: "lock.open", active: "lock.open.fill"),
        
        // Media & Entertainment
        "television": SymbolPair(normal: "tv", active: "tv.fill"),
        "cast": SymbolPair(normal: "airplayvideo", active: "airplayvideo"),
        "speaker": SymbolPair(normal: "speaker.wave.2", active: "speaker.wave.2.fill"),
        "volume-high": SymbolPair(normal: "speaker.wave.3", active: "speaker.wave.3.fill"),
        "play": SymbolPair(normal: "play.fill", active: "play.fill"),
        "pause": SymbolPair(normal: "pause.fill", active: "pause.fill"),
        "music": SymbolPair(normal: "music.note", active: "music.note"),
        
        // Security & Sensors
        "motion-sensor": SymbolPair(normal: "sensor.motion", active: "sensor.motion.fill"),
        "run": SymbolPair(normal: "figure.walk", active: "figure.run"),
        "shield-home": SymbolPair(normal: "shield", active: "shield.fill"),
        "shield-lock": SymbolPair(normal: "shield.lefthalf.filled", active: "shield.fill"),
        "shield-check": SymbolPair(normal: "shield.checkmark", active: "shield.checkmark.fill"),
        "bell": SymbolPair(normal: "bell", active: "bell.fill"),
        "cctv": SymbolPair(normal: "video", active: "video.fill"),
        "camera": SymbolPair(normal: "video", active: "video.fill"),
        
        // Navigation & Rooms
        "home": SymbolPair(normal: "house", active: "house.fill"),
        "home-outline": SymbolPair(normal: "house", active: "house.fill"),
        "bed": SymbolPair(normal: "bed.double", active: "bed.double.fill"),
        "sofa": SymbolPair(normal: "sofa", active: "sofa.fill"),
        "silverware-fork-knife": SymbolPair(normal: "fork.knife", active: "fork.knife"),
        "shower": SymbolPair(normal: "shower", active: "shower.fill"),
        "car": SymbolPair(normal: "car", active: "car.fill"),
        "robot-vacuum": SymbolPair(normal: "circle.grid.cross", active: "circle.grid.cross.fill"),
        "account": SymbolPair(normal: "person", active: "person.fill"),
        "account-group": SymbolPair(normal: "person.2", active: "person.2.fill"),
        "cog": SymbolPair(normal: "gearshape", active: "gearshape.fill"),
        "information": SymbolPair(normal: "info.circle", active: "info.circle.fill")
    ]
    
    private static func domainFallback(domain: String, isActive: Bool) -> String {
        switch domain {
        case "light":
            return isActive ? "lightbulb.fill" : "lightbulb"
        case "switch", "input_boolean":
            return isActive ? "power.circle.fill" : "power"
        case "climate":
            return isActive ? "thermometer.sun.fill" : "thermometer.medium"
        case "fan":
            return isActive ? "fan.fill" : "fan"
        case "cover":
            return isActive ? "curtains.open" : "curtains.closed"
        case "lock":
            return isActive ? "lock.open.fill" : "lock.fill"
        case "media_player":
            return isActive ? "tv.fill" : "tv"
        case "camera":
            return isActive ? "video.fill" : "video"
        case "sensor":
            return "gauge.with.needle"
        case "binary_sensor":
            return isActive ? "sensor.motion.fill" : "sensor.motion"
        case "vacuum":
            return isActive ? "circle.grid.cross.fill" : "circle.grid.cross"
        case "scene":
            return "sparkles"
        case "script":
            return "applescript"
        case "automation":
            return "gearshape.2"
        case "person":
            return isActive ? "person.fill" : "person"
        case "weather":
            return "cloud.sun.fill"
        default:
            return isActive ? "circle.fill" : "circle"
        }
    }
}
