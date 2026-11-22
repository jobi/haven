import XCTest
@testable import NativeHACore

final class WidgetDataServiceTests: XCTestCase {

    func testServiceCallMappingByDomain() {
        let light = WidgetDataService.serviceCall(for: "light", currentState: "on")
        XCTAssertEqual(light.domain, "light")
        XCTAssertEqual(light.service, "toggle")

        let lockLocked = WidgetDataService.serviceCall(for: "lock", currentState: "locked")
        XCTAssertEqual(lockLocked.domain, "lock")
        XCTAssertEqual(lockLocked.service, "unlock")

        let lockUnlocked = WidgetDataService.serviceCall(for: "lock", currentState: "unlocked")
        XCTAssertEqual(lockUnlocked.domain, "lock")
        XCTAssertEqual(lockUnlocked.service, "lock")

        let coverOpen = WidgetDataService.serviceCall(for: "cover", currentState: "open")
        XCTAssertEqual(coverOpen.domain, "cover")
        XCTAssertEqual(coverOpen.service, "close_cover")

        let coverClosed = WidgetDataService.serviceCall(for: "cover", currentState: "closed")
        XCTAssertEqual(coverClosed.domain, "cover")
        XCTAssertEqual(coverClosed.service, "open_cover")

        let scene = WidgetDataService.serviceCall(for: "scene", currentState: "scening")
        XCTAssertEqual(scene.domain, "scene")
        XCTAssertEqual(scene.service, "turn_on")

        let media = WidgetDataService.serviceCall(for: "media_player", currentState: "playing")
        XCTAssertEqual(media.domain, "media_player")
        XCTAssertEqual(media.service, "media_play_pause")
    }

    func testWidgetEntitySnapshotFormattingAndFlags() {
        let sensor = WidgetEntitySnapshot(
            entityId: "sensor.living_room_temperature",
            friendlyName: "Living Room Temperature",
            domain: "sensor",
            state: "72.4",
            icon: "mdi:thermometer",
            unitOfMeasurement: "°F"
        )
        XCTAssertEqual(sensor.formattedState, "72.4 °F")
        XCTAssertFalse(sensor.isControllable)

        let lightOn = WidgetEntitySnapshot(
            entityId: "light.kitchen",
            friendlyName: "Kitchen",
            domain: "light",
            state: "on"
        )
        XCTAssertTrue(lightOn.isActive)
        XCTAssertTrue(lightOn.isControllable)
        XCTAssertEqual(lightOn.formattedState, "On")

        let lockLocked = WidgetEntitySnapshot(
            entityId: "lock.front_door",
            friendlyName: "Front Door",
            domain: "lock",
            state: "locked"
        )
        XCTAssertTrue(lockLocked.isActive)
        XCTAssertTrue(lockLocked.isControllable)
    }

    func testSnapshotRoundTripPersistence() {
        let sample = [
            WidgetEntitySnapshot(
                entityId: "light.test_widget_lamp",
                serverId: "server-a",
                friendlyName: "Test Lamp A",
                domain: "light",
                state: "on",
                icon: "mdi:lamp"
            )
        ]
        let sampleB = [
            WidgetEntitySnapshot(
                entityId: "light.test_widget_lamp",
                serverId: "server-b",
                friendlyName: "Test Lamp B",
                domain: "light",
                state: "off",
                icon: "mdi:lamp"
            )
        ]
        SharedAppGroup.saveEntitySnapshots(sample, forServerId: "server-a")
        SharedAppGroup.saveEntitySnapshots(sampleB, forServerId: "server-b")
        
        let loadedA = SharedAppGroup.loadEntitySnapshots(forServerId: "server-a")
        let loadedB = SharedAppGroup.loadEntitySnapshots(forServerId: "server-b")
        
        XCTAssertEqual(loadedA.count, 1)
        XCTAssertEqual(loadedA.first?.friendlyName, "Test Lamp A")
        XCTAssertEqual(loadedA.first?.state, "on")
        XCTAssertEqual(loadedA.first?.serverId, "server-a")
        
        XCTAssertEqual(loadedB.count, 1)
        XCTAssertEqual(loadedB.first?.friendlyName, "Test Lamp B")
        XCTAssertEqual(loadedB.first?.state, "off")
        XCTAssertEqual(loadedB.first?.serverId, "server-b")
        XCTAssertNotEqual(loadedA.first?.id, loadedB.first?.id)
        
        SharedAppGroup.removeEntitySnapshots(forServerId: "server-a")
        SharedAppGroup.removeEntitySnapshots(forServerId: "server-b")
    }
}
