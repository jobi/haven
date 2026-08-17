import XCTest
@testable import NativeHACore

@MainActor
final class EntityDeltaTests: XCTestCase {
    
    func testInitialDumpAndDeltaPatching() throws {
        let store = EntityStore()
        
        // 1. Ingest initial state dump
        let initialData = MockDataFixtures.sampleEntityInitialDumpJSON.data(using: .utf8)!
        let initialAnyCodable = try JSONDecoder().decode(AnyCodable.self, from: initialData)
        store.processEntityEvent(initialAnyCodable)
        
        XCTAssertEqual(store.entities.count, 4)
        
        let light = try XCTUnwrap(store.entity(for: "light.living_room_ceiling"))
        XCTAssertEqual(light.state, "on")
        XCTAssertTrue(light.isOn)
        XCTAssertEqual(light.friendlyName, "Living Room Ceiling")
        XCTAssertEqual(light.brightness, 204.0)
        XCTAssertEqual(light.brightnessPercentage, (204.0 / 255.0) * 100.0)
        
        let door = try XCTUnwrap(store.entity(for: "binary_sensor.front_door"))
        XCTAssertEqual(door.state, "off")
        XCTAssertFalse(door.isOn)
        
        // 2. Ingest compressed delta updates
        let deltaData = MockDataFixtures.sampleEntityDeltaJSON.data(using: .utf8)!
        let deltaAnyCodable = try JSONDecoder().decode(AnyCodable.self, from: deltaData)
        store.processEntityEvent(deltaAnyCodable)
        
        let updatedLight = try XCTUnwrap(store.entity(for: "light.living_room_ceiling"))
        XCTAssertEqual(updatedLight.state, "off")
        XCTAssertFalse(updatedLight.isOn)
        XCTAssertEqual(updatedLight.friendlyName, "Living Room Ceiling") // Preserved from initial dump
        XCTAssertEqual(updatedLight.brightness, 0.0)
        
        let updatedDoor = try XCTUnwrap(store.entity(for: "binary_sensor.front_door"))
        XCTAssertEqual(updatedDoor.state, "on")
        XCTAssertTrue(updatedDoor.isOn)
    }
}
