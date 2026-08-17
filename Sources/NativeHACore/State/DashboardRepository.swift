import Foundation
import Observation

@Observable
@MainActor
public final class DashboardRepository {
    public private(set) var availableDashboards: [LovelaceDashboardSummary] = []
    public private(set) var currentDashboardConfig: LovelaceConfig?
    public private(set) var sectionViews: [LovelaceView] = []
    
    public var selectedDashboardId: String? {
        didSet {
            if let id = selectedDashboardId {
                UserDefaults.standard.set(id, forKey: lastSelectedDashboardKey)
            }
        }
    }
    
    public var selectedViewId: String? {
        didSet {
            if let id = selectedViewId {
                UserDefaults.standard.set(id, forKey: lastSelectedViewKey)
            }
        }
    }
    
    public var isLoading: Bool = false
    public var errorMessage: String?
    
    private weak var wsClient: HAWebSocketClient?
    private let lastSelectedDashboardKey = "ha_last_selected_dashboard_id"
    private let lastSelectedViewKey = "ha_last_selected_view_id"
    
    public init(wsClient: HAWebSocketClient? = nil) {
        self.wsClient = wsClient
        self.selectedDashboardId = UserDefaults.standard.string(forKey: lastSelectedDashboardKey)
        self.selectedViewId = UserDefaults.standard.string(forKey: lastSelectedViewKey)
    }
    
    public func setWebSocketClient(_ client: HAWebSocketClient) {
        self.wsClient = client
    }
    
    // MARK: - Fetch Dashboards
    public func loadDashboards() async {
        guard let client = wsClient else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch custom dashboards list
            var dashboards: [LovelaceDashboardSummary] = []
            
            // Add default main dashboard (id: "lovelace", url_path: nil)
            dashboards.append(LovelaceDashboardSummary(
                id: "default",
                urlPath: nil,
                title: "Default Dashboard",
                icon: "mdi:view-dashboard"
            ))
            
            if let result = try await client.sendCommand(type: "lovelace/dashboards/list") {
                if let array = result.arrayValue {
                    let decoder = JSONDecoder()
                    for item in array {
                        if let data = try? JSONEncoder().encode(item),
                           let summary = try? decoder.decode(LovelaceDashboardSummary.self, from: data) {
                            dashboards.append(summary)
                        }
                    }
                }
            }
            
            self.availableDashboards = dashboards
            
            // Restore saved dashboard if present, otherwise default to first/saved
            let savedId = UserDefaults.standard.string(forKey: lastSelectedDashboardKey)
            let targetId: String
            if let saved = savedId, dashboards.contains(where: { $0.id == saved }) {
                targetId = saved
            } else if let selected = selectedDashboardId, dashboards.contains(where: { $0.id == selected }) {
                targetId = selected
            } else {
                targetId = "default"
            }
            
            await selectDashboard(id: targetId)
            
        } catch {
            self.errorMessage = "Failed to load dashboards: \(error.localizedDescription)"
        }
        
        self.isLoading = false
    }
    
    // MARK: - Select & Load Specific Dashboard
    public func selectDashboard(id: String) async {
        guard let client = wsClient else { return }
        self.selectedDashboardId = id
        UserDefaults.standard.set(id, forKey: lastSelectedDashboardKey)
        
        self.isLoading = true
        self.errorMessage = nil
        
        let targetSummary = availableDashboards.first(where: { $0.id == id })
        let urlPath = targetSummary?.urlPath
        
        do {
            let result = try await client.sendCommand(
                type: "lovelace/config",
                urlPath: urlPath
            )
            
            if let result = result {
                let data = try JSONEncoder().encode(result)
                let config = try JSONDecoder().decode(LovelaceConfig.self, from: data)
                self.currentDashboardConfig = config
                
                // Filter views for "sections" type
                let filteredSections = config.views.filter { $0.isSectionsType }
                self.sectionViews = filteredSections
                
                // Restore saved view if valid, otherwise select first
                let savedViewId = UserDefaults.standard.string(forKey: lastSelectedViewKey)
                if let saved = savedViewId, filteredSections.contains(where: { $0.id == saved }) {
                    self.selectedViewId = saved
                } else if let first = filteredSections.first {
                    self.selectedViewId = first.id
                } else {
                    self.selectedViewId = nil
                }
            }
        } catch {
            self.errorMessage = "Failed to load dashboard configuration: \(error.localizedDescription)"
        }
        
        self.isLoading = false
    }
    
    public var currentSelectedView: LovelaceView? {
        guard let id = selectedViewId else { return sectionViews.first }
        return sectionViews.first(where: { $0.id == id }) ?? sectionViews.first
    }
}
