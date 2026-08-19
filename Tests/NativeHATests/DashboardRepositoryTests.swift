import XCTest
@testable import NativeHACore

@MainActor
final class DashboardRepositoryTests: XCTestCase {
    
    private var testUserDefaults: UserDefaults!
    private let suiteName = "com.haven.tests.dashboardrepo"
    
    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: suiteName)
        testUserDefaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
    
    func testPerServerDashboardSelectionMemory() {
        // Server 1 setup
        let repo = DashboardRepository(userDefaults: testUserDefaults, serverId: "server-home")
        XCTAssertNil(repo.selectedDashboardId)
        
        // Select dashboard & view for Server 1
        repo.selectedDashboardId = "dash-living-room"
        repo.selectedViewId = "view-lights"
        
        // Switch to Server 2
        repo.serverId = "server-cabin"
        XCTAssertNil(repo.selectedDashboardId)
        XCTAssertNil(repo.selectedViewId)
        
        // Select dashboard & view for Server 2
        repo.selectedDashboardId = "dash-energy"
        repo.selectedViewId = "view-solar"
        
        // Switch back to Server 1
        repo.serverId = "server-home"
        XCTAssertEqual(repo.selectedDashboardId, "dash-living-room")
        XCTAssertEqual(repo.selectedViewId, "view-lights")
        
        // Switch back to Server 2
        repo.serverId = "server-cabin"
        XCTAssertEqual(repo.selectedDashboardId, "dash-energy")
        XCTAssertEqual(repo.selectedViewId, "view-solar")
    }
}
