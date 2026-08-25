import XCTest
@testable import NativeHACore

final class DemoModeTests: XCTestCase {
    
    func testDemoServerConfiguration() {
        let server = ServerConfig.demoServer
        XCTAssertTrue(server.isDemo)
        XCTAssertEqual(server.id, ServerConfig.demoServerId)
        XCTAssertEqual(server.name, "Demo Smart Home")
        XCTAssertEqual(server.url.host, "demo.haven.local")
    }
    
    func testDemoDataProviderEntities() {
        let entities = DemoDataProvider.shared.generateDemoEntities()
        XCTAssertGreaterThanOrEqual(entities.count, 20)
        
        // Person John
        guard let john = entities["person.john"] else {
            XCTFail("Missing person.john entity")
            return
        }
        XCTAssertEqual(john.state, "home")
        XCTAssertEqual(john.attributes["friendly_name"]?.stringValue, "John")
        
        // Light
        guard let light = entities["light.living_room_ceiling"] else {
            XCTFail("Missing light.living_room_ceiling entity")
            return
        }
        XCTAssertEqual(light.state, "on")
        XCTAssertEqual(light.attributes["brightness"]?.intValue, 215)
        
        // Climate
        guard let climate = entities["climate.main_floor"] else {
            XCTFail("Missing climate.main_floor entity")
            return
        }
        XCTAssertEqual(climate.state, "heat_cool")
        XCTAssertEqual(climate.attributes["current_temperature"]?.doubleValue, 72.0)
        
        // Media Player
        guard let media = entities["media_player.living_room_tv"] else {
            XCTFail("Missing media_player.living_room_tv entity")
            return
        }
        XCTAssertEqual(media.state, "playing")
        XCTAssertEqual(media.attributes["media_title"]?.stringValue, "Midnight City")
        XCTAssertEqual(media.attributes["media_artist"]?.stringValue, "M83")
        
        // Gauges & Sensors
        XCTAssertNotNil(entities["sensor.home_power_consumption"])
        XCTAssertNotNil(entities["sensor.solar_generation"])
        XCTAssertNotNil(entities["camera.backyard"])
        XCTAssertNotNil(entities["lock.front_door"])
    }
    
    func testDemoDashboardConfiguration() {
        let dashboard = DemoDataProvider.shared.generateDemoDashboard()
        XCTAssertEqual(dashboard.views.count, 3)
        
        let overview = dashboard.views[0]
        XCTAssertEqual(overview.title, "Home")
        XCTAssertTrue(overview.isSectionsType)
        XCTAssertGreaterThanOrEqual(overview.badges?.count ?? 0, 3)
        XCTAssertGreaterThanOrEqual(overview.sections?.count ?? 0, 4)
        
        let security = dashboard.views[1]
        XCTAssertEqual(security.title, "Security")
        XCTAssertGreaterThanOrEqual(security.sections?.count ?? 0, 2)
        
        let energy = dashboard.views[2]
        XCTAssertEqual(energy.title, "Energy & Climate")
        XCTAssertGreaterThanOrEqual(energy.sections?.count ?? 0, 2)
    }
    
    @MainActor
    func testInteractiveEntityStoreInDemoMode() async {
        let store = EntityStore()
        store.loadDemoData()
        XCTAssertTrue(store.isDemoMode)
        
        // 1. Toggle light
        XCTAssertEqual(store.entity(for: "light.living_room_ceiling")?.state, "on")
        await store.toggle(entityId: "light.living_room_ceiling")
        XCTAssertEqual(store.entity(for: "light.living_room_ceiling")?.state, "off")
        await store.toggle(entityId: "light.living_room_ceiling")
        XCTAssertEqual(store.entity(for: "light.living_room_ceiling")?.state, "on")
        
        // 2. Set brightness
        await store.setBrightness(entityId: "light.living_room_ceiling", percentage: 50)
        let newBrightness = store.entity(for: "light.living_room_ceiling")?.attributes["brightness"]?.intValue
        XCTAssertEqual(newBrightness, 127)
        
        // 3. Unlock and Lock
        XCTAssertEqual(store.entity(for: "lock.front_door")?.state, "locked")
        await store.setLock(entityId: "lock.front_door", lock: false)
        XCTAssertEqual(store.entity(for: "lock.front_door")?.state, "unlocked")
        await store.setLock(entityId: "lock.front_door", lock: true)
        XCTAssertEqual(store.entity(for: "lock.front_door")?.state, "locked")
        
        // 4. Media Play/Pause
        XCTAssertEqual(store.entity(for: "media_player.living_room_tv")?.state, "playing")
        await store.mediaPlayPause(entityId: "media_player.living_room_tv")
        XCTAssertEqual(store.entity(for: "media_player.living_room_tv")?.state, "paused")
        
        // 5. Climate adjustment
        await store.callService(
            domain: "climate",
            service: "set_temperature",
            target: ["entity_id": AnyCodable("climate.main_floor")],
            serviceData: ["temperature": AnyCodable(69.5)]
        )
        XCTAssertEqual(store.entity(for: "climate.main_floor")?.attributes["temperature"]?.doubleValue, 69.5)
    }
    
    @MainActor
    func testDashboardRepositoryDemoMode() async {
        let repo = DashboardRepository()
        repo.loadDemoDashboards()
        
        XCTAssertTrue(repo.isDemoMode)
        XCTAssertEqual(repo.availableDashboards.count, 1)
        XCTAssertEqual(repo.availableDashboards.first?.id, "demo")
        XCTAssertEqual(repo.sectionViews.count, 3)
        XCTAssertEqual(repo.selectedViewId, "home")
    }
}
