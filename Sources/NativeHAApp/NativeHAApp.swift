import SwiftUI
import NativeHACore

@main
struct NativeHAApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isConfigured {
                    DashboardHostView(
                        repository: appState.dashboardRepository,
                        entityStore: appState.entityStore,
                        connectionState: appState.connectionState,
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
                            serverConfig: appState.activeServer,
                            connectionState: appState.connectionState,
                            onReloadDashboards: {
                                Task {
                                    await appState.dashboardRepository.loadDashboards()
                                }
                            },
                            onDisconnect: {
                                appState.logout()
                            }
                        )
                    }
                } else {
                    ServerSetupView { server in
                        appState.setServerAndLogin(server)
                    }
                }
            }
            .task {
                if appState.isConfigured {
                    await appState.connect()
                }
            }
        }
    }
}
