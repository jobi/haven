import XCTest
@testable import NativeHACore

final class ServerStoreTests: XCTestCase {
    
    private var testUserDefaults: UserDefaults!
    private let suiteName = "com.haven.tests.serverstore"
    
    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: suiteName)
        testUserDefaults.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }
    
    func testAddAndRetrieveServers() {
        let store = ServerStore(userDefaults: testUserDefaults)
        XCTAssertFalse(store.hasServers)
        
        let server1 = ServerConfig(id: "s1", name: "Home", url: URL(string: "http://home.local:8123")!)
        let server2 = ServerConfig(id: "s2", name: "Cabin", url: URL(string: "http://cabin.local:8123")!)
        
        store.addServer(server1)
        XCTAssertTrue(store.hasServers)
        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.activeServerId, "s1")
        XCTAssertEqual(store.activeServer?.name, "Home")
        
        store.addServer(server2, makeActive: false)
        XCTAssertEqual(store.servers.count, 2)
        XCTAssertEqual(store.activeServerId, "s1")
        
        store.setActiveServer(id: "s2")
        XCTAssertEqual(store.activeServerId, "s2")
        XCTAssertEqual(store.activeServer?.name, "Cabin")
    }
    
    func testServerRemoval() {
        let store = ServerStore(userDefaults: testUserDefaults)
        let server1 = ServerConfig(id: "s1", name: "Home", url: URL(string: "http://home.local:8123")!)
        let server2 = ServerConfig(id: "s2", name: "Cabin", url: URL(string: "http://cabin.local:8123")!)
        
        store.addServer(server1)
        store.addServer(server2)
        store.setActiveServer(id: "s1")
        
        store.removeServer(id: "s1")
        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.activeServerId, "s2")
        
        store.removeServer(id: "s2")
        XCTAssertFalse(store.hasServers)
        XCTAssertNil(store.activeServerId)
    }
    
    func testLegacyMigration() {
        // Pre-populate legacy single-server key
        let legacyServer = ServerConfig(id: "legacy-1", name: "Legacy Home", url: URL(string: "http://legacy.local:8123")!)
        let data = try! JSONEncoder().encode(legacyServer)
        testUserDefaults.set(data, forKey: "nativeha_active_server_v1")
        
        let store = ServerStore(userDefaults: testUserDefaults)
        XCTAssertTrue(store.hasServers)
        XCTAssertEqual(store.servers.count, 1)
        XCTAssertEqual(store.activeServerId, "legacy-1")
        XCTAssertEqual(store.activeServer?.name, "Legacy Home")
    }
}
