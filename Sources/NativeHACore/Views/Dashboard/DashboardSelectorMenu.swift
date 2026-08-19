import SwiftUI

public struct DashboardSelectorMenu: View {
    @Bindable var repository: DashboardRepository
    var serverStore: ServerStore?
    var onSwitchServer: ((String) -> Void)?
    var onAddServer: (() -> Void)?
    
    public init(
        repository: DashboardRepository,
        serverStore: ServerStore? = nil,
        onSwitchServer: ((String) -> Void)? = nil,
        onAddServer: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.serverStore = serverStore
        self.onSwitchServer = onSwitchServer
        self.onAddServer = onAddServer
    }
    
    public var body: some View {
        Menu {
            // Servers Section
            if let store = serverStore, !store.servers.isEmpty {
                Section("Servers") {
                    ForEach(store.servers) { server in
                        Button {
                            #if os(iOS)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            onSwitchServer?(server.id)
                        } label: {
                            HStack {
                                Text(server.name)
                                if server.id == store.activeServerId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    
                    Button {
                        onAddServer?()
                    } label: {
                        Label("Add Server...", systemImage: "plus")
                    }
                }
            }
            
            // Dashboards Section
            Section("Dashboards") {
                ForEach(repository.availableDashboards) { dashboard in
                    Button {
                        Task {
                            await repository.selectDashboard(id: dashboard.id)
                        }
                    } label: {
                        HStack {
                            Text(dashboard.displayName)
                            if dashboard.id == repository.selectedDashboardId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            // Views Section
            if !repository.sectionViews.isEmpty {
                Section("Views") {
                    ForEach(repository.sectionViews) { view in
                        Button {
                            repository.selectedViewId = view.id
                        } label: {
                            HStack {
                                if let icon = view.icon {
                                    Image(systemName: IconMapper.sfSymbol(for: icon))
                                }
                                Text(view.displayName)
                                if view.id == repository.selectedViewId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(currentTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.haCardBackground)
            )
        }
    }
    
    private var currentTitle: String {
        let serverName = serverStore?.activeServer?.name
        let dash = repository.availableDashboards.first(where: { $0.id == repository.selectedDashboardId })?.displayName ?? "Dashboard"
        
        if let currentView = repository.currentSelectedView, repository.sectionViews.count > 1 {
            return "\(dash) • \(currentView.displayName)"
        }
        
        if let sName = serverName, (serverStore?.servers.count ?? 0) > 1, sName.lowercased() != dash.lowercased() {
            return "\(sName) • \(dash)"
        }
        
        return dash
    }
}
