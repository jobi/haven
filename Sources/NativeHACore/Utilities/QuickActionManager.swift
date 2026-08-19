import Foundation
#if os(iOS)
import UIKit

public struct QuickActionManager: Sendable {
    public static let shared = QuickActionManager()
    
    public static let addServerType = "com.nativeha.add_server"
    public static let serverPrefix = "com.nativeha.server."
    
    public init() {}
    
    /// Synchronizes the Home Screen 3D Touch / Long-Press Quick Action menu items with configured servers.
    @MainActor
    public func syncQuickActions(servers: [ServerConfig], activeServerId: String?) {
        var items: [UIApplicationShortcutItem] = []
        
        // Add up to 3 configured servers
        for server in servers.prefix(3) {
            let isCurrent = (server.id == activeServerId)
            let iconName = isCurrent ? "checkmark.circle.fill" : "house.fill"
            let icon = UIApplicationShortcutIcon(systemImageName: iconName)
            
            let item = UIApplicationShortcutItem(
                type: "\(Self.serverPrefix)\(server.id)",
                localizedTitle: server.name,
                localizedSubtitle: server.url.host ?? server.url.absoluteString,
                icon: icon,
                userInfo: ["serverId": server.id as NSString]
            )
            items.append(item)
        }
        
        // Add "Add Server" shortcut
        let addIcon = UIApplicationShortcutIcon(systemImageName: "plus")
        let addItem = UIApplicationShortcutItem(
            type: Self.addServerType,
            localizedTitle: "Add Server",
            localizedSubtitle: "Connect another instance",
            icon: addIcon,
            userInfo: nil
        )
        items.append(addItem)
        
        UIApplication.shared.shortcutItems = items
    }
    
    /// Extracts server ID from a quick action shortcut item
    public func extractServerId(from shortcutItem: UIApplicationShortcutItem) -> String? {
        if let serverId = shortcutItem.userInfo?["serverId"] as? String {
            return serverId
        }
        if shortcutItem.type.hasPrefix(Self.serverPrefix) {
            return String(shortcutItem.type.dropFirst(Self.serverPrefix.count))
        }
        return nil
    }
    
    /// Checks if the shortcut item is for adding a new server
    public func isAddServerAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        shortcutItem.type == Self.addServerType
    }
}
#else
public struct QuickActionManager: Sendable {
    public static let shared = QuickActionManager()
    public init() {}
    public func syncQuickActions(servers: [ServerConfig], activeServerId: String?) {}
}
#endif
