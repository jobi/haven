import Foundation

/// Provides mock entities and Lovelace dashboard definitions for Demo Mode.
public final class DemoDataProvider: Sendable {
    public static let shared = DemoDataProvider()
    
    public init() {}
    
    // MARK: - Demo Entities
    public func generateDemoEntities() -> [String: HAEntityState] {
        var map: [String: HAEntityState] = [:]
        
        func add(_ id: String, state: String, attributes: [String: Any]) {
            var raw: [String: AnyCodable] = [:]
            for (k, v) in attributes {
                if let str = v as? String {
                    raw[k] = AnyCodable(str)
                } else if let num = v as? Int {
                    raw[k] = AnyCodable(num)
                } else if let dbl = v as? Double {
                    raw[k] = AnyCodable(dbl)
                } else if let b = v as? Bool {
                    raw[k] = AnyCodable(b)
                } else if let arr = v as? [String] {
                    raw[k] = AnyCodable(arr.map { AnyCodable($0) })
                } else if let arr = v as? [Double] {
                    raw[k] = AnyCodable(arr.map { AnyCodable($0) })
                } else if let arr = v as? [Int] {
                    raw[k] = AnyCodable(arr.map { AnyCodable($0) })
                }
            }
            map[id] = HAEntityState(
                entityId: id,
                state: state,
                attributes: raw,
                lastChanged: Date(),
                lastUpdated: Date()
            )
        }
        
        // 1. Person Entities (Using "John" as requested)
        add("person.john", state: "home", attributes: [
            "friendly_name": "John",
            "source": "device_tracker.johns_iphone",
            "latitude": 37.7749,
            "longitude": -122.4194,
            "gps_accuracy": 10
        ])
        
        add("person.sarah", state: "home", attributes: [
            "friendly_name": "Sarah",
            "source": "device_tracker.sarahs_iphone"
        ])
        
        // 2. Lights
        add("light.living_room_ceiling", state: "on", attributes: [
            "friendly_name": "Living Room Ceiling",
            "brightness": 215,
            "color_mode": "color_temp",
            "supported_color_modes": ["color_temp", "hs", "rgb"],
            "color_temp": 320,
            "min_mireds": 153,
            "max_mireds": 500
        ])
        
        add("light.kitchen_island", state: "on", attributes: [
            "friendly_name": "Kitchen Island Lights",
            "brightness": 255,
            "color_mode": "hs",
            "supported_color_modes": ["hs", "rgb", "color_temp"],
            "hs_color": [42.0, 85.0],
            "rgb_color": [255, 204, 102]
        ])
        
        add("light.dining_chandelier", state: "off", attributes: [
            "friendly_name": "Dining Room Chandelier",
            "brightness": 128,
            "supported_color_modes": ["brightness"]
        ])
        
        add("light.bedroom_accent", state: "on", attributes: [
            "friendly_name": "Bedroom Accent Light",
            "brightness": 180,
            "color_mode": "hs",
            "supported_color_modes": ["hs", "rgb"],
            "hs_color": [280.0, 75.0],
            "rgb_color": [180, 70, 240]
        ])
        
        add("light.patio_string_lights", state: "off", attributes: [
            "friendly_name": "Patio String Lights",
            "supported_color_modes": ["onoff"]
        ])
        
        // 3. Switches & Fans
        add("switch.espresso_machine", state: "on", attributes: [
            "friendly_name": "Espresso Machine",
            "icon": "mdi:coffee-maker"
        ])
        
        add("switch.garden_irrigation", state: "off", attributes: [
            "friendly_name": "Garden Irrigation",
            "icon": "mdi:sprinkler"
        ])
        
        add("switch.pool_pump", state: "on", attributes: [
            "friendly_name": "Pool Filtration Pump",
            "icon": "mdi:pump"
        ])
        
        add("fan.living_room_ceiling_fan", state: "on", attributes: [
            "friendly_name": "Ceiling Fan",
            "percentage": 66,
            "oscillating": true,
            "direction": "forward"
        ])
        
        // 4. Covers & Locks
        add("cover.living_room_blinds", state: "open", attributes: [
            "friendly_name": "Living Room Blinds",
            "current_position": 85,
            "device_class": "blind"
        ])
        
        add("cover.garage_door", state: "closed", attributes: [
            "friendly_name": "Garage Door",
            "current_position": 0,
            "device_class": "garage"
        ])
        
        add("lock.front_door", state: "locked", attributes: [
            "friendly_name": "Front Door Lock"
        ])
        
        // 5. Climate / Thermostats
        add("climate.main_floor", state: "heat_cool", attributes: [
            "friendly_name": "Main Floor Thermostat",
            "current_temperature": 72.0,
            "temperature": 72.0,
            "target_temp_high": 75.0,
            "target_temp_low": 68.0,
            "min_temp": 50.0,
            "max_temp": 90.0,
            "hvac_modes": ["off", "heat", "cool", "heat_cool", "auto"],
            "hvac_action": "idle",
            "fan_mode": "auto",
            "fan_modes": ["auto", "on", "diffuse"]
        ])
        
        add("climate.upstairs", state: "cool", attributes: [
            "friendly_name": "Upstairs HVAC",
            "current_temperature": 74.0,
            "temperature": 71.0,
            "min_temp": 50.0,
            "max_temp": 90.0,
            "hvac_modes": ["off", "cool", "heat"],
            "hvac_action": "cooling"
        ])
        
        // 6. Media Players
        add("media_player.living_room_tv", state: "playing", attributes: [
            "friendly_name": "Living Room Apple TV",
            "media_title": "Midnight City",
            "media_artist": "M83",
            "media_album_name": "Hurry Up, We're Dreaming",
            "media_content_type": "music",
            "volume_level": 0.55,
            "is_volume_muted": false,
            "source": "Apple Music",
            "source_list": ["Apple Music", "YouTube", "Plex", "AirPlay"]
        ])
        
        add("media_player.kitchen_speaker", state: "idle", attributes: [
            "friendly_name": "Kitchen HomePod",
            "volume_level": 0.40,
            "is_volume_muted": false
        ])
        
        // 7. Sensors & Gauges
        add("sensor.living_room_temperature", state: "72.4", attributes: [
            "friendly_name": "Living Room Temperature",
            "unit_of_measurement": "°F",
            "device_class": "temperature",
            "state_class": "measurement"
        ])
        
        add("sensor.living_room_humidity", state: "45", attributes: [
            "friendly_name": "Living Room Humidity",
            "unit_of_measurement": "%",
            "device_class": "humidity",
            "state_class": "measurement"
        ])
        
        add("sensor.home_power_consumption", state: "1420", attributes: [
            "friendly_name": "Home Power Consumption",
            "unit_of_measurement": "W",
            "device_class": "power",
            "state_class": "measurement"
        ])
        
        add("sensor.solar_generation", state: "2850", attributes: [
            "friendly_name": "Solar Power Production",
            "unit_of_measurement": "W",
            "device_class": "power",
            "state_class": "measurement"
        ])
        
        add("sensor.air_quality_index", state: "28", attributes: [
            "friendly_name": "Indoor Air Quality",
            "unit_of_measurement": "AQI",
            "device_class": "aqi"
        ])
        
        add("sensor.battery_smoke_detector", state: "94", attributes: [
            "friendly_name": "Smoke Detector Battery",
            "unit_of_measurement": "%",
            "device_class": "battery"
        ])
        
        add("sensor.lights_active_count", state: "3", attributes: [
            "friendly_name": "Active Lights",
            "unit_of_measurement": "lights",
            "icon": "mdi:lightbulb-group"
        ])
        
        // 8. Binary Sensors
        add("binary_sensor.front_door", state: "off", attributes: [
            "friendly_name": "Front Door",
            "device_class": "door"
        ])
        
        add("binary_sensor.front_door_motion", state: "off", attributes: [
            "friendly_name": "Front Porch Motion",
            "device_class": "motion"
        ])
        
        add("binary_sensor.backyard_motion", state: "on", attributes: [
            "friendly_name": "Backyard Motion",
            "device_class": "motion"
        ])
        
        add("binary_sensor.smoke_detector", state: "off", attributes: [
            "friendly_name": "Smoke Alarm",
            "device_class": "smoke"
        ])
        
        // 9. Environment & Sun
        add("sun.sun", state: "above_horizon", attributes: [
            "friendly_name": "Sun",
            "elevation": 42.5,
            "azimuth": 178.2,
            "rising": true
        ])
        
        add("weather.home", state: "sunny", attributes: [
            "friendly_name": "Home Weather",
            "temperature": 75,
            "humidity": 42,
            "pressure": 1014,
            "wind_speed": 6
        ])
        
        // 10. Cameras
        add("camera.backyard", state: "idle", attributes: [
            "friendly_name": "Backyard Nest Cam",
            "frontend_stream_types": ["web_rtc", "hls"],
            "access_token": "demo_token_backyard"
        ])
        
        add("camera.front_door", state: "idle", attributes: [
            "friendly_name": "Front Doorbell Cam",
            "frontend_stream_types": ["web_rtc", "hls"],
            "access_token": "demo_token_front_door"
        ])
        
        add("camera.living_room", state: "idle", attributes: [
            "friendly_name": "Living Room Cam",
            "frontend_stream_types": ["web_rtc", "hls"],
            "access_token": "demo_token_living_room"
        ])
        
        return map
    }
    
    // MARK: - Demo Dashboard Configuration
    public func generateDemoDashboard() -> LovelaceConfig {
        func rawCard(_ type: String, _ dict: [String: Any]) -> AnyCardConfig {
            var raw: [String: AnyCodable] = ["type": AnyCodable(type)]
            for (k, v) in dict {
                if let str = v as? String {
                    raw[k] = AnyCodable(str)
                } else if let num = v as? Int {
                    raw[k] = AnyCodable(num)
                } else if let dbl = v as? Double {
                    raw[k] = AnyCodable(dbl)
                } else if let b = v as? Bool {
                    raw[k] = AnyCodable(b)
                } else if let arr = v as? [String] {
                    raw[k] = AnyCodable(arr.map { AnyCodable($0) })
                } else if let map = v as? [String: Double] {
                    var m: [String: AnyCodable] = [:]
                    for (mk, mv) in map { m[mk] = AnyCodable(mv) }
                    raw[k] = AnyCodable(m)
                } else if let arr = v as? [[String: Any]] {
                    var encodedList: [AnyCodable] = []
                    for item in arr {
                        var m: [String: AnyCodable] = [:]
                        for (ik, iv) in item {
                            if let s = iv as? String { m[ik] = AnyCodable(s) }
                            else if let n = iv as? Int { m[ik] = AnyCodable(n) }
                            else if let d = iv as? Double { m[ik] = AnyCodable(d) }
                        }
                        encodedList.append(AnyCodable(m))
                    }
                    raw[k] = AnyCodable(encodedList)
                }
            }
            return AnyCardConfig(type: type, rawData: raw)
        }
        
        // --- View 1: Overview (Sections) ---
        let overviewBadges: [AnyCardConfig] = [
            rawCard("badge", ["entity": "person.john"]),
            rawCard("badge", ["entity": "sensor.living_room_temperature"]),
            rawCard("badge", ["entity": "climate.main_floor"]),
            rawCard("badge", ["entity": "sensor.lights_active_count"]),
            rawCard("badge", ["entity": "lock.front_door"])
        ]
        
        let secQuickControls = LovelaceSection(
            id: "sec_quick_controls",
            title: "Quick Controls",
            cards: [
                rawCard("tile", ["entity": "light.living_room_ceiling", "icon": "mdi:ceiling-light"]),
                rawCard("tile", ["entity": "light.kitchen_island", "icon": "mdi:island"]),
                rawCard("tile", ["entity": "switch.espresso_machine", "icon": "mdi:coffee-maker"]),
                rawCard("tile", ["entity": "cover.living_room_blinds", "icon": "mdi:blinds"]),
                rawCard("tile", ["entity": "fan.living_room_ceiling_fan", "icon": "mdi:fan"]),
                rawCard("tile", ["entity": "lock.front_door", "icon": "mdi:lock"])
            ]
        )
        
        let secClimateEnergy = LovelaceSection(
            id: "sec_climate_energy",
            title: "Climate & Energy",
            cards: [
                rawCard("tile", ["entity": "climate.main_floor", "name": "Main Floor Thermostat"]),
                rawCard("gauge", [
                    "entity": "sensor.home_power_consumption",
                    "name": "Power Consumption",
                    "unit": "W",
                    "min": 0.0,
                    "max": 4000.0,
                    "severity": ["green": 1000.0, "yellow": 2000.0, "red": 3000.0],
                    "needle": true
                ]),
                rawCard("gauge", [
                    "entity": "sensor.solar_generation",
                    "name": "Solar Generation",
                    "unit": "W",
                    "min": 0.0,
                    "max": 5000.0,
                    "severity": ["green": 2000.0, "yellow": 1000.0, "red": 0.0],
                    "needle": true
                ])
            ]
        )
        
        let secSecurityCameras = LovelaceSection(
            id: "sec_security",
            title: "Security & Cameras",
            cards: [
                rawCard("picture-entity", ["entity": "camera.backyard", "name": "Backyard Cam", "show_state": false]),
                rawCard("picture-entity", ["entity": "camera.front_door", "name": "Front Porch Cam", "show_state": false]),
                rawCard("tile", ["entity": "binary_sensor.front_door", "icon": "mdi:door"]),
                rawCard("tile", ["entity": "binary_sensor.backyard_motion", "icon": "mdi:motion-sensor"])
            ]
        )
        
        let secEntertainment = LovelaceSection(
            id: "sec_entertainment",
            title: "Living Room Media",
            cards: [
                rawCard("media-control", ["entity": "media_player.living_room_tv"]),
                rawCard("tile", ["entity": "media_player.kitchen_speaker"])
            ]
        )
        
        let secEnvironment = LovelaceSection(
            id: "sec_environment",
            title: "Environment & Sensors",
            cards: [
                rawCard("sensor", ["entity": "sensor.living_room_temperature", "name": "Temperature (24h)", "graph": "line", "hours_to_show": 24]),
                rawCard("sensor", ["entity": "sensor.living_room_humidity", "name": "Humidity (24h)", "graph": "line", "hours_to_show": 24]),
                rawCard("tile", ["entity": "sensor.air_quality_index", "icon": "mdi:air-filter"]),
                rawCard("tile", ["entity": "sensor.battery_smoke_detector", "icon": "mdi:battery"])
            ]
        )
        
        let viewOverview = LovelaceView(
            title: "Home",
            path: "home",
            icon: "mdi:home-variant",
            type: "sections",
            badges: overviewBadges,
            sections: [secQuickControls, secClimateEnergy, secSecurityCameras, secEntertainment, secEnvironment]
        )
        
        // --- View 2: Cameras & Security ---
        let secCamGrid = LovelaceSection(
            id: "sec_cam_grid",
            title: "Live Camera Feeds",
            cards: [
                rawCard("picture-entity", ["entity": "camera.backyard", "name": "Backyard", "show_state": true]),
                rawCard("picture-entity", ["entity": "camera.front_door", "name": "Front Door", "show_state": true]),
                rawCard("picture-entity", ["entity": "camera.living_room", "name": "Living Room", "show_state": true])
            ]
        )
        
        let secAccessControl = LovelaceSection(
            id: "sec_access",
            title: "Perimeter & Access",
            cards: [
                rawCard("tile", ["entity": "lock.front_door"]),
                rawCard("tile", ["entity": "cover.garage_door"]),
                rawCard("tile", ["entity": "binary_sensor.front_door"]),
                rawCard("tile", ["entity": "binary_sensor.front_door_motion"]),
                rawCard("tile", ["entity": "binary_sensor.backyard_motion"]),
                rawCard("tile", ["entity": "binary_sensor.smoke_detector"])
            ]
        )
        
        let viewSecurity = LovelaceView(
            title: "Security",
            path: "security",
            icon: "mdi:shield-home",
            type: "sections",
            sections: [secCamGrid, secAccessControl]
        )
        
        // --- View 3: Climate & Energy ---
        let secEnergyGauges = LovelaceSection(
            id: "sec_energy_detail",
            title: "Real-Time Energy",
            cards: [
                rawCard("gauge", [
                    "entity": "sensor.home_power_consumption",
                    "name": "Power Usage",
                    "unit": "W",
                    "min": 0.0,
                    "max": 5000.0,
                    "severity": ["green": 1200.0, "yellow": 2500.0, "red": 3500.0],
                    "needle": true
                ]),
                rawCard("gauge", [
                    "entity": "sensor.solar_generation",
                    "name": "Solar Production",
                    "unit": "W",
                    "min": 0.0,
                    "max": 5000.0,
                    "severity": ["green": 2500.0, "yellow": 1000.0, "red": 0.0],
                    "needle": true
                ])
            ]
        )
        
        let secThermostats = LovelaceSection(
            id: "sec_thermostats",
            title: "HVAC Zones",
            cards: [
                rawCard("tile", ["entity": "climate.main_floor", "name": "Main Floor (Heat/Cool)"]),
                rawCard("tile", ["entity": "climate.upstairs", "name": "Upstairs (Cooling)"]),
                rawCard("sensor", ["entity": "sensor.living_room_temperature", "name": "Living Room Temperature", "graph": "line", "hours_to_show": 24])
            ]
        )
        
        let viewEnergy = LovelaceView(
            title: "Energy & Climate",
            path: "energy",
            icon: "mdi:solar-power",
            type: "sections",
            sections: [secEnergyGauges, secThermostats]
        )
        
        return LovelaceConfig(
            title: "Haven Demo Home",
            views: [viewOverview, viewSecurity, viewEnergy]
        )
    }
}
