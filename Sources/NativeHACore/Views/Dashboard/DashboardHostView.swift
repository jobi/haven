import SwiftUI

public struct DashboardHostView: View {
    @Bindable var repository: DashboardRepository
    var entityStore: EntityStore
    var connectionState: HAConnectionState
    var onOpenSettings: () -> Void
    var onReconnect: () -> Void
    
    @State private var selectedEntityIdForMoreInfo: String? = nil
    @State private var isShowingMoreInfo: Bool = false
    
    public init(
        repository: DashboardRepository,
        entityStore: EntityStore,
        connectionState: HAConnectionState,
        onOpenSettings: @escaping () -> Void,
        onReconnect: @escaping () -> Void
    ) {
        self.repository = repository
        self.entityStore = entityStore
        self.connectionState = connectionState
        self.onOpenSettings = onOpenSettings
        self.onReconnect = onReconnect
    }
    
    public var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitViewLayout
        } else {
            stackLayout
        }
        #else
        splitViewLayout
        #endif
    }
    
    // MARK: - iPhone Stack Layout
    private var stackLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection Banner if not connected
                if !connectionState.isConnected {
                    connectionBanner
                }
                
                // View Selector Tab Bar (if multiple section views exist)
                if repository.sectionViews.count > 1 {
                    viewTabsBar
                }
                
                // Main Content
                if repository.isLoading && repository.sectionViews.isEmpty {
                    loadingView
                } else if let currentView = repository.currentSelectedView {
                    SectionViewContainer(
                        viewConfig: currentView,
                        entityStore: entityStore,
                        onMoreInfo: { entityId in
                            selectedEntityIdForMoreInfo = entityId
                            isShowingMoreInfo = true
                        },
                        onRefresh: {
                            await repository.loadDashboards()
                        }
                    )
                } else {
                    emptyStateView
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DashboardSelectorMenu(repository: repository)
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                }
                #endif
            }
            .sheet(isPresented: $isShowingMoreInfo) {
                if let entityId = selectedEntityIdForMoreInfo,
                   let entity = entityStore.entity(for: entityId) {
                    EntityMoreInfoSheet(entity: entity, entityStore: entityStore)
                }
            }
        }
    }
    
    // MARK: - iPad Split View Layout
    private var splitViewLayout: some View {
        NavigationSplitView {
            List(selection: $repository.selectedViewId) {
                Section("Dashboards") {
                    ForEach(repository.availableDashboards) { dashboard in
                        Button {
                            Task {
                                await repository.selectDashboard(id: dashboard.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                    .foregroundStyle(dashboard.id == repository.selectedDashboardId ? Color.haBlue : .secondary)
                                Text(dashboard.displayName)
                                    .fontWeight(dashboard.id == repository.selectedDashboardId ? .bold : .regular)
                            }
                        }
                    }
                }
                
                if !repository.sectionViews.isEmpty {
                    Section("Views") {
                        ForEach(repository.sectionViews) { view in
                            NavigationLink(value: view.id) {
                                HStack {
                                    if let icon = view.icon {
                                        Image(systemName: IconMapper.sfSymbol(for: icon))
                                    }
                                    Text(view.displayName)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Home Assistant")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        } detail: {
            VStack(spacing: 0) {
                if !connectionState.isConnected {
                    connectionBanner
                }
                
                if let currentView = repository.currentSelectedView {
                    SectionViewContainer(
                        viewConfig: currentView,
                        entityStore: entityStore,
                        onMoreInfo: { entityId in
                            selectedEntityIdForMoreInfo = entityId
                            isShowingMoreInfo = true
                        },
                        onRefresh: {
                            await repository.loadDashboards()
                        }
                    )
                } else {
                    emptyStateView
                }
            }
            .sheet(isPresented: $isShowingMoreInfo) {
                if let entityId = selectedEntityIdForMoreInfo,
                   let entity = entityStore.entity(for: entityId) {
                    EntityMoreInfoSheet(entity: entity, entityStore: entityStore)
                }
            }
        }
    }
    
    // MARK: - Subviews
    private var viewTabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(repository.sectionViews) { view in
                    let isSelected = view.id == repository.selectedViewId
                    Button {
                        repository.selectedViewId = view.id
                    } label: {
                        HStack(spacing: 6) {
                            if let icon = view.icon {
                                Image(systemName: IconMapper.sfSymbol(for: icon, isActive: isSelected))
                                    .font(.caption)
                            }
                            Text(view.displayName)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.haBlue : Color.haCardBackground)
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.haBackground)
    }
    
    private var connectionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .foregroundStyle(.orange)
            
            Text(connectionState.description)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button("Retry") {
                onReconnect()
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.haBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading section dashboard...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.haBackground)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Section Dashboards Found")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
            
            Text("Create a Section-based dashboard in Home Assistant to view it natively.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.haBackground)
    }
}
