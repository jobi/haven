import SwiftUI

/// Native SwiftUI showcase of Haven's WidgetKit widgets (Small Quick Entity, Medium & Large Control Grids)
/// used via the `-widgets_preview` launch argument for automated App Store screenshot generation.
public struct WidgetShowcaseView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    public init() {}
    
    private var livingRoomLight: WidgetEntitySnapshot {
        WidgetEntitySnapshot(
            entityId: "light.living_room_ceiling",
            serverId: "demo-server",
            friendlyName: "Living Room",
            domain: "light",
            state: "on",
            icon: "mdi:ceiling-light"
        )
    }
    
    private var temperatureSensor: WidgetEntitySnapshot {
        WidgetEntitySnapshot(
            entityId: "sensor.living_room_temperature",
            serverId: "demo-server",
            friendlyName: "Living Room Temp",
            domain: "sensor",
            state: "72.4",
            icon: "mdi:thermometer",
            unitOfMeasurement: "°F"
        )
    }
    
    private var cabinThermostat: WidgetEntitySnapshot {
        WidgetEntitySnapshot(
            entityId: "climate.cabin_heater",
            serverId: "cabin-server",
            friendlyName: "Cabin Heat",
            domain: "climate",
            state: "heat",
            icon: "mdi:thermostat"
        )
    }
    
    private var solarPower: WidgetEntitySnapshot {
        WidgetEntitySnapshot(
            entityId: "sensor.solar_power",
            serverId: "demo-server",
            friendlyName: "Solar Output",
            domain: "sensor",
            state: "4.2",
            icon: "mdi:solar-power",
            unitOfMeasurement: "kW"
        )
    }
    
    private var mediumEntities: [WidgetEntitySnapshot] {
        [
            livingRoomLight,
            WidgetEntitySnapshot(entityId: "light.kitchen_island", serverId: "demo-server", friendlyName: "Kitchen", domain: "light", state: "off", icon: "mdi:lightbulb"),
            WidgetEntitySnapshot(entityId: "lock.front_door", serverId: "demo-server", friendlyName: "Front Door", domain: "lock", state: "locked", icon: "mdi:lock"),
            WidgetEntitySnapshot(entityId: "cover.garage_door", serverId: "demo-server", friendlyName: "Garage Door", domain: "cover", state: "closed", icon: "mdi:garage")
        ]
    }
    
    private var largeEntities: [WidgetEntitySnapshot] {
        [
            livingRoomLight,
            WidgetEntitySnapshot(entityId: "light.kitchen_island", serverId: "demo-server", friendlyName: "Kitchen", domain: "light", state: "on", icon: "mdi:lightbulb-group"),
            WidgetEntitySnapshot(entityId: "lock.front_door", serverId: "demo-server", friendlyName: "Front Door", domain: "lock", state: "locked", icon: "mdi:lock"),
            WidgetEntitySnapshot(entityId: "climate.living_room", serverId: "demo-server", friendlyName: "Thermostat", domain: "climate", state: "heat", icon: "mdi:thermostat"),
            WidgetEntitySnapshot(entityId: "fan.bedroom_fan", serverId: "demo-server", friendlyName: "Bedroom Fan", domain: "fan", state: "on", icon: "mdi:fan"),
            WidgetEntitySnapshot(entityId: "scene.movie_night", serverId: "demo-server", friendlyName: "Movie Night", domain: "scene", state: "active", icon: "mdi:movie-open")
        ]
    }
    
    private var cabinEntities: [WidgetEntitySnapshot] {
        [
            WidgetEntitySnapshot(entityId: "light.porch", serverId: "cabin-server", friendlyName: "Porch Light", domain: "light", state: "on", icon: "mdi:outdoor-lamp"),
            WidgetEntitySnapshot(entityId: "lock.cabin_door", serverId: "cabin-server", friendlyName: "Cabin Door", domain: "lock", state: "locked", icon: "mdi:lock"),
            WidgetEntitySnapshot(entityId: "climate.cabin_heater", serverId: "cabin-server", friendlyName: "Cabin Heat", domain: "climate", state: "heat", icon: "mdi:thermostat"),
            WidgetEntitySnapshot(entityId: "sensor.cabin_temp", serverId: "cabin-server", friendlyName: "Indoor Temp", domain: "sensor", state: "68.0", icon: "mdi:thermometer", unitOfMeasurement: "°F"),
            WidgetEntitySnapshot(entityId: "switch.water_heater", serverId: "cabin-server", friendlyName: "Water Heater", domain: "switch", state: "on", icon: "mdi:power-plug"),
            WidgetEntitySnapshot(entityId: "scene.arrive_cabin", serverId: "cabin-server", friendlyName: "Arrive Mode", domain: "scene", state: "active", icon: "mdi:home")
        ]
    }
    
    public var body: some View {
        ZStack {
            // Clean iOS-style wallpaper gradient backdrop
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.22, blue: 0.42),
                    Color(red: 0.18, green: 0.34, blue: 0.56),
                    Color(red: 0.28, green: 0.45, blue: 0.64)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if sizeClass == .regular {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
    }
    
    private var iphoneLayout: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Interactive Widgets")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Home Screen • HomeView • CarPlay • StandBy")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .padding(.top, 10)
            
            // Row 1: Two Small Quick Entity Widgets
            HStack(spacing: 16) {
                widgetWrapper(label: "Haven") {
                    smallEntityCard(snapshot: livingRoomLight)
                        .frame(height: 158)
                }
                widgetWrapper(label: "Haven") {
                    smallEntityCard(snapshot: temperatureSensor)
                        .frame(height: 158)
                }
            }
            
            // Row 2: Medium Control Grid Widget
            widgetWrapper(label: "Haven") {
                controlGridCard(title: "Home Controls", serverName: "Main Home", snapshots: mediumEntities, isLarge: false)
                    .frame(height: 158)
            }
            
            // Row 3: Large Control Grid Widget
            widgetWrapper(label: "Haven") {
                controlGridCard(title: "Living Spaces", serverName: "Main Home", snapshots: largeEntities, isLarge: true)
                    .frame(height: 290)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }
    
    private var ipadLayout: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Interactive Home Widgets")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Home Screen • HomeView • CarPlay • StandBy — Pinned Per Server")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.top, 36)
            
            // Row 1: Main Home (Small x2 + Medium on left, Large on right)
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        widgetWrapper(label: "Haven") {
                            smallEntityCard(snapshot: livingRoomLight)
                                .frame(height: 192)
                        }
                        widgetWrapper(label: "Haven") {
                            smallEntityCard(snapshot: temperatureSensor)
                                .frame(height: 192)
                        }
                    }
                    
                    widgetWrapper(label: "Haven") {
                        controlGridCard(title: "Quick Controls", serverName: "Main Home", snapshots: mediumEntities, isLarge: false)
                            .frame(height: 192)
                    }
                }
                .frame(maxWidth: 440)
                
                widgetWrapper(label: "Haven") {
                    controlGridCard(title: "Living Spaces", serverName: "Main Home", snapshots: largeEntities, isLarge: true)
                        .frame(height: 432)
                }
                .frame(maxWidth: 440)
            }
            
            // Row 2: Second Server (Mountain Cabin Large on left, Small x2 + Medium on right)
            HStack(alignment: .top, spacing: 28) {
                widgetWrapper(label: "Haven") {
                    controlGridCard(title: "Mountain Cabin", serverName: "Cabin Server", snapshots: cabinEntities, isLarge: true)
                        .frame(height: 432)
                }
                .frame(maxWidth: 440)
                
                VStack(spacing: 24) {
                    widgetWrapper(label: "Haven") {
                        controlGridCard(title: "Cabin Quick Access", serverName: "Cabin Server", snapshots: Array(cabinEntities.prefix(4)), isLarge: false)
                            .frame(height: 192)
                    }
                    
                    HStack(spacing: 20) {
                        widgetWrapper(label: "Haven") {
                            smallEntityCard(snapshot: cabinThermostat)
                                .frame(height: 192)
                        }
                        widgetWrapper(label: "Haven") {
                            smallEntityCard(snapshot: solarPower)
                                .frame(height: 192)
                        }
                    }
                }
                .frame(maxWidth: 440)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 48)
    }
    
    private func widgetWrapper<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 6) {
            content()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
    }
    
    private func accentColor(for snapshot: WidgetEntitySnapshot) -> Color {
        guard snapshot.isActive else { return .secondary }
        switch snapshot.domain {
        case "light": return .orange
        case "switch", "input_boolean", "fan", "automation": return .blue
        case "climate": return .red
        case "lock": return .green
        case "cover": return .indigo
        case "scene", "script": return .purple
        case "media_player": return .pink
        default: return .blue
        }
    }
    
    private func smallEntityCard(snapshot: WidgetEntitySnapshot) -> some View {
        let accent = accentColor(for: snapshot)
        let symbol = snapshot.sfSymbolName
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(snapshot.isActive ? accent.opacity(0.22) : Color.primary.opacity(0.08))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(snapshot.isActive ? accent : .secondary)
                }
                
                Spacer()
                
                if snapshot.isControllable {
                    Image(systemName: snapshot.isActive ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(snapshot.isActive ? accent : .secondary)
                }
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(snapshot.friendlyName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(snapshot.formattedState)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(snapshot.isActive ? accent : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            ZStack {
                Color.haCardBackground
                if snapshot.isActive {
                    LinearGradient(
                        colors: [accent.opacity(0.18), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }
    
    private func controlGridCard(
        title: String,
        serverName: String,
        snapshots: [WidgetEntitySnapshot],
        isLarge: Bool
    ) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return VStack(alignment: .leading, spacing: 8) {
            if isLarge {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(serverName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
            }
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(snapshots) { snapshot in
                    gridTile(snapshot: snapshot, compact: !isLarge)
                        .frame(minHeight: isLarge ? 74 : 58)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.haCardBackground)
    }
    
    private func gridTile(snapshot: WidgetEntitySnapshot, compact: Bool) -> some View {
        let accent = accentColor(for: snapshot)
        let symbol = snapshot.sfSymbolName
        
        return HStack(spacing: compact ? 8 : 10) {
            ZStack {
                Circle()
                    .fill(snapshot.isActive ? accent.opacity(0.22) : Color.primary.opacity(0.08))
                    .frame(width: compact ? 32 : 36, height: compact ? 32 : 36)
                
                Image(systemName: symbol)
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(snapshot.isActive ? accent : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.friendlyName)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(snapshot.formattedState)
                    .font(.system(size: compact ? 11 : 12, weight: .medium, design: .rounded))
                    .foregroundStyle(snapshot.isActive ? accent : .secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(snapshot.isActive ? accent.opacity(0.12) : Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    snapshot.isActive ? accent.opacity(0.28) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}
