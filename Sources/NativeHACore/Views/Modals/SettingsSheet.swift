import SwiftUI

public struct SettingsSheet: View {
    let serverConfig: ServerConfig?
    let connectionState: HAConnectionState
    let onReloadDashboards: () -> Void
    let onDisconnect: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    public init(
        serverConfig: ServerConfig?,
        connectionState: HAConnectionState,
        onReloadDashboards: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) {
        self.serverConfig = serverConfig
        self.connectionState = connectionState
        self.onReloadDashboards = onReloadDashboards
        self.onDisconnect = onDisconnect
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Active Server") {
                    HStack {
                        Text("Server Name")
                        Spacer()
                        Text(serverConfig?.name ?? "Home Assistant")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(serverConfig?.url.absoluteString ?? "-")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(connectionState.description)
                            .font(.caption)
                            .foregroundStyle(connectionState.isConnected ? Color.green : Color.orange)
                    }
                }
                
                Section("Actions") {
                    Button {
                        onReloadDashboards()
                        dismiss()
                    } label: {
                        Label("Reload Dashboards", systemImage: "arrow.clockwise")
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        onDisconnect()
                        dismiss()
                    } label: {
                        Label("Disconnect & Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("NativeHA Client")
                        Spacer()
                        Text("v1.0.0 (Native SwiftUI)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
