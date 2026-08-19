import SwiftUI

public struct SettingsSheet: View {
    let serverStore: ServerStore
    let connectionState: HAConnectionState
    let onSwitchServer: (String) -> Void
    let onAddServer: () -> Void
    let onReloadDashboards: () -> Void
    let onRemoveServer: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    public init(
        serverStore: ServerStore,
        connectionState: HAConnectionState,
        onSwitchServer: @escaping (String) -> Void,
        onAddServer: @escaping () -> Void,
        onReloadDashboards: @escaping () -> Void,
        onRemoveServer: @escaping (String) -> Void
    ) {
        self.serverStore = serverStore
        self.connectionState = connectionState
        self.onSwitchServer = onSwitchServer
        self.onAddServer = onAddServer
        self.onReloadDashboards = onReloadDashboards
        self.onRemoveServer = onRemoveServer
    }
    
    public var body: some View {
        NavigationStack {
            List {
                // Servers Section
                Section {
                    ForEach(serverStore.servers) { server in
                        let isActive = (server.id == serverStore.activeServerId)
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            onSwitchServer(server.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "server.rack")
                                    .font(.title3)
                                    .foregroundStyle(isActive ? Color.haBlue : Color.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(server.name)
                                            .font(.body.weight(isActive ? .semibold : .regular))
                                            .foregroundStyle(.primary)
                                        if isActive {
                                            Text("Active")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Color.haBlue)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule()
                                                        .fill(Color.haBlue.opacity(0.12))
                                                )
                                        }
                                    }
                                    
                                    Text(server.url.absoluteString)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if isActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.haBlue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if serverStore.servers.count > 1 {
                                Button(role: .destructive) {
                                    onRemoveServer(server.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    
                    Button {
                        onAddServer()
                    } label: {
                        Label("Add Another Server", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.haBlue)
                    }
                } header: {
                    Text("Configured Servers")
                } footer: {
                    Text("Long-press the Haven icon on your Home Screen to quickly switch servers before opening.")
                }
                
                // Connection Status
                if let active = serverStore.activeServer {
                    Section("Current Connection") {
                        HStack {
                            Text("Active Server")
                            Spacer()
                            Text(active.name)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(connectionState.description)
                                .font(.caption)
                                .foregroundStyle(connectionState.isConnected ? Color.green : Color.orange)
                        }
                    }
                }
                
                // Actions
                Section("Actions") {
                    Button {
                        onReloadDashboards()
                        dismiss()
                    } label: {
                        Label("Reload Dashboards", systemImage: "arrow.clockwise")
                    }
                }
                
                // Disconnect Current Server
                if let active = serverStore.activeServer {
                    Section {
                        Button(role: .destructive) {
                            onRemoveServer(active.id)
                            dismiss()
                        } label: {
                            Label("Disconnect Active Server", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Haven for Home Assistant")
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
