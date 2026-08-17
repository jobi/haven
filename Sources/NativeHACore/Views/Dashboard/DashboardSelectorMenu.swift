import SwiftUI

public struct DashboardSelectorMenu: View {
    @Bindable var repository: DashboardRepository
    
    public init(repository: DashboardRepository) {
        self.repository = repository
    }
    
    public var body: some View {
        Menu {
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
        let dash = repository.availableDashboards.first(where: { $0.id == repository.selectedDashboardId })?.displayName ?? "Dashboard"
        if let currentView = repository.currentSelectedView, repository.sectionViews.count > 1 {
            return "\(dash) • \(currentView.displayName)"
        }
        return dash
    }
}
