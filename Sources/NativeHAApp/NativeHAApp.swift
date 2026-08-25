import SwiftUI
import NativeHACore
#if os(iOS)
import UIKit
#endif

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    var appState: AppState?
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            appState?.handleQuickAction(shortcutItem: shortcutItem)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        NotificationCenter.default.post(
            name: .havenDidPerformQuickAction,
            object: shortcutItem
        )
        completionHandler(true)
    }
}

extension Notification.Name {
    static let havenDidPerformQuickAction = Notification.Name("havenDidPerformQuickAction")
}
#endif

@main
struct NativeHAApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isConfigured {
                    DashboardHostView(
                        repository: appState.dashboardRepository,
                        entityStore: appState.entityStore,
                        connectionState: appState.connectionState,
                        serverStore: appState.serverStore,
                        externalMoreInfoEntityId: $appState.presentedMoreInfoEntityId,
                        onSwitchServer: { serverId in
                            appState.switchToServer(id: serverId)
                        },
                        onAddServer: {
                            appState.isShowingAddServerSheet = true
                        },
                        onOpenSettings: {
                            appState.isShowingSettings = true
                        },
                        onReconnect: {
                            Task {
                                await appState.connect()
                            }
                        }
                    )
                    .sheet(isPresented: $appState.isShowingSettings) {
                        SettingsSheet(
                            serverStore: appState.serverStore,
                            connectionState: appState.connectionState,
                            onSwitchServer: { serverId in
                                appState.switchToServer(id: serverId)
                            },
                            onAddServer: {
                                appState.isShowingSettings = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    appState.isShowingAddServerSheet = true
                                }
                            },
                            onReloadDashboards: {
                                Task {
                                    await appState.dashboardRepository.loadDashboards()
                                }
                            },
                            onRemoveServer: { serverId in
                                appState.removeServer(id: serverId)
                            }
                        )
                    }
                    .sheet(isPresented: $appState.isShowingAddServerSheet) {
                        ServerSetupView { server in
                            appState.addServerAndLogin(server)
                        }
                    }
                } else {
                    ServerSetupView { server in
                        appState.addServerAndLogin(server)
                    }
                }
            }
            .task {
                #if os(iOS)
                appDelegate.appState = appState
                #endif
                if appState.isConfigured {
                    await appState.connect()
                }
            }
            .onOpenURL { url in
                appState.handleDeepLink(url)
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: .havenDidPerformQuickAction)) { notification in
                if let item = notification.object as? UIApplicationShortcutItem {
                    appState.handleQuickAction(shortcutItem: item)
                }
            }
            #endif
        }
    }
}
