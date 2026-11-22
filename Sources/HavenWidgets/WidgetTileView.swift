import AppIntents
import NativeHACore
import SwiftUI
import WidgetKit

/// Shared styling and tile components for Haven widgets across HomeView, CarPlay, StandBy, and iOS.
enum WidgetPalette {
    static func accentColor(for snapshot: WidgetEntitySnapshot) -> Color {
        guard snapshot.isActive else { return .secondary }
        switch snapshot.domain {
        case "light":
            return .orange
        case "switch", "input_boolean", "fan", "automation":
            return .blue
        case "climate":
            return .red
        case "lock":
            return .green
        case "cover":
            return .indigo
        case "scene", "script":
            return .purple
        case "media_player":
            return .pink
        default:
            return .blue
        }
    }
    
    static func deepLinkURL(for snapshot: WidgetEntitySnapshot) -> URL {
        var components = URLComponents()
        components.scheme = "haven"
        components.host = "entity"
        var items = [URLQueryItem(name: "more_info", value: snapshot.entityId)]
        if let serverId = snapshot.serverId, !serverId.isEmpty {
            items.append(URLQueryItem(name: "server_id", value: serverId))
        }
        components.queryItems = items
        return components.url ?? URL(string: "haven://")!
    }
}

/// Interactive tile used in the Control Grid widget (Medium & Large) and HomeView.
struct WidgetEntityTile: View {
    let snapshot: WidgetEntitySnapshot
    let compact: Bool
    
    var body: some View {
        if snapshot.isControllable {
            Button(intent: ToggleEntityIntent(entityId: snapshot.entityId, serverId: snapshot.serverId)) {
                tileContent
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: WidgetPalette.deepLinkURL(for: snapshot)) {
                tileContent
            }
        }
    }
    
    private var tileContent: some View {
        let accent = WidgetPalette.accentColor(for: snapshot)
        let symbol = snapshot.sfSymbolName
        
        return HStack(spacing: compact ? 8 : 10) {
            ZStack {
                Circle()
                    .fill(snapshot.isActive ? accent.opacity(0.22) : Color.primary.opacity(0.08))
                    .frame(width: compact ? 32 : 36, height: compact ? 32 : 36)
                
                Image(systemName: symbol)
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(snapshot.isActive ? accent : .secondary)
                    .widgetAccentable()
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
