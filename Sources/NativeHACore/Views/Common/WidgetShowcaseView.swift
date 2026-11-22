import SwiftUI

/// Native SwiftUI showcase of Haven's full WidgetKit suite (Quick Entity, Option Picker,
/// Thermostat, Media Player, and Home Controls Grid) used via `-widgets_preview` for App Store screenshots.
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
    
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.20, blue: 0.39),
                    Color(red: 0.17, green: 0.32, blue: 0.54),
                    Color(red: 0.26, green: 0.43, blue: 0.63)
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
    
    // MARK: - iPhone Layout (Showcases All 5 Widget Classes)
    
    private var iphoneLayout: some View {
        VStack(spacing: 14) {
            VStack(spacing: 3) {
                Text("Interactive Widgets")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Home Screen • HomeView • CarPlay • StandBy")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
            }
            .padding(.top, 6)
            
            // Row 1: Small Quick Entity + Small Option Picker
            HStack(spacing: 14) {
                widgetWrapper(label: "Quick Entity") {
                    smallEntityCard(snapshot: livingRoomLight)
                        .frame(height: 152)
                }
                widgetWrapper(label: "Option Picker") {
                    smallOptionPickerCard(
                        title: "Home Mode",
                        options: ["Home", "Movie", "Sleep"],
                        selected: "Movie"
                    )
                    .frame(height: 152)
                }
            }
            
            // Row 2: Medium Thermostat Widget
            widgetWrapper(label: "Thermostat") {
                mediumThermostatCard()
                    .frame(height: 152)
            }
            
            // Row 3: Medium Media Player Widget
            widgetWrapper(label: "Media Player") {
                mediumMediaPlayerCard()
                    .frame(height: 146)
            }
            
            // Row 4: Medium Home Controls Grid
            widgetWrapper(label: "Home Controls") {
                controlGridCard(title: "Home Controls", serverName: "Main Home", snapshots: mediumEntities, isLarge: false)
                    .frame(height: 148)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
    
    // MARK: - iPad 13" Layout (Showcases All 5 Widget Classes + Multi-Server)
    
    private var ipadLayout: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Interactive Home Widgets")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Quick Entities • Thermostats • Media Players • Option Pickers • Control Grids")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .padding(.top, 32)
            
            // Row 1: Left (Small x2 + Medium Thermostat), Right (Large Controls Grid)
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 22) {
                    HStack(spacing: 20) {
                        widgetWrapper(label: "Quick Entity") {
                            smallEntityCard(snapshot: livingRoomLight)
                                .frame(height: 188)
                        }
                        widgetWrapper(label: "Quick Entity") {
                            smallEntityCard(snapshot: temperatureSensor)
                                .frame(height: 188)
                        }
                    }
                    
                    widgetWrapper(label: "Thermostat") {
                        mediumThermostatCard()
                            .frame(height: 188)
                    }
                }
                .frame(maxWidth: 440)
                
                widgetWrapper(label: "Home Controls Grid") {
                    controlGridCard(title: "Living Spaces", serverName: "Main Home", snapshots: largeEntities, isLarge: true)
                        .frame(height: 424)
                }
                .frame(maxWidth: 440)
            }
            
            // Row 2: Left (Medium Media Player + Medium Option Picker), Right (Large Option Picker / Media)
            HStack(alignment: .top, spacing: 28) {
                widgetWrapper(label: "Media Player") {
                    mediumMediaPlayerCard()
                        .frame(height: 196)
                }
                .frame(maxWidth: 440)
                
                widgetWrapper(label: "Option Picker") {
                    mediumOptionPickerCard(
                        title: "Home Mode",
                        subtitle: "Movie",
                        options: ["Home", "Away", "Movie", "Sleep"],
                        selected: "Movie"
                    )
                    .frame(height: 196)
                }
                .frame(maxWidth: 440)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 48)
    }
    
    // MARK: - Widget Wrapper
    
    private func widgetWrapper<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 5) {
            content()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - 1. Quick Entity Small Card
    
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
                        .frame(width: 42, height: 42)
                    Image(systemName: symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(snapshot.isActive ? accent : .secondary)
                }
                Spacer()
                if snapshot.isControllable {
                    Image(systemName: snapshot.isActive ? "power.circle.fill" : "power.circle")
                        .font(.system(size: 25, weight: .medium))
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
                    LinearGradient(colors: [accent.opacity(0.18), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        }
    }
    
    // MARK: - 2. Option Picker Cards (Small & Medium)
    
    private func smallOptionPickerCard(title: String, options: [String], selected: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.indigo)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            
            VStack(spacing: 5) {
                ForEach(options, id: \.self) { opt in
                    let isSel = (opt == selected)
                    HStack(spacing: 5) {
                        if isSel {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text(opt)
                            .font(.system(size: 11, weight: isSel ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isSel ? .white : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSel ? Color.indigo : Color.primary.opacity(0.07))
                    )
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.haCardBackground)
    }
    
    private func mediumOptionPickerCard(title: String, subtitle: String, options: [String], selected: String) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.indigo)
                }
                Spacer()
            }
            .padding(.horizontal, 2)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    let isSel = (opt == selected)
                    HStack(spacing: 6) {
                        if isSel {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text(opt)
                            .font(.system(size: 13, weight: isSel ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isSel ? .white : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSel ? Color.indigo : Color.primary.opacity(0.07))
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.haCardBackground)
    }
    
    // MARK: - 3. Medium Thermostat Card
    
    private func mediumThermostatCard() -> some View {
        let modes: [(name: String, symbol: String, color: Color, selected: Bool)] = [
            ("Off", "power", .secondary, false),
            ("Heat", "flame.fill", .orange, true),
            ("Cool", "snowflake", .cyan, false),
            ("Auto", "thermometer.sun.fill", .teal, false)
        ]
        
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Living Room")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("71°")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Heating")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("Set 72°")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 8) {
                    ForEach(["minus", "plus"], id: \.self) { sym in
                        Image(systemName: sym)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 5) {
                ForEach(modes, id: \.name) { m in
                    HStack(spacing: 6) {
                        Image(systemName: m.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(m.selected ? .white : m.color)
                        Text(m.name)
                            .font(.system(size: 11, weight: m.selected ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(m.selected ? .white : .primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(m.selected ? m.color : Color.primary.opacity(0.06))
                    )
                }
            }
            .frame(width: 106)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.haCardBackground
                LinearGradient(colors: [Color.orange.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
    
    // MARK: - 4. Medium Media Player Card
    
    private func mediumMediaPlayerCard() -> some View {
        HStack(spacing: 14) {
            // Album artwork mock
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.purple, Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "music.note")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(width: 112, height: 112)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.pink)
                    Text("Living Room Speaker")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Midnight City")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("M83")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 6) {
                    mediaBtn("backward.fill", prominent: false)
                    mediaBtn("pause.fill", prominent: true)
                    mediaBtn("forward.fill", prominent: false)
                    mediaBtn("speaker.wave.1.fill", prominent: false)
                    mediaBtn("speaker.wave.3.fill", prominent: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.haCardBackground
                LinearGradient(colors: [Color.pink.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
    
    private func mediaBtn(_ symbol: String, prominent: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: prominent ? 14 : 12, weight: .bold))
            .foregroundStyle(prominent ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(prominent ? Color.pink : Color.primary.opacity(0.08))
            )
    }
    
    // MARK: - 5. Control Grid Card
    
    private func controlGridCard(
        title: String,
        serverName: String,
        snapshots: [WidgetEntitySnapshot],
        isLarge: Bool
    ) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
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
                        .frame(minHeight: isLarge ? 74 : 54)
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
                    .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                Image(systemName: symbol)
                    .font(.system(size: compact ? 14 : 17, weight: .semibold))
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
        .padding(.vertical, compact ? 7 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(snapshot.isActive ? accent.opacity(0.12) : Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(snapshot.isActive ? accent.opacity(0.28) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
