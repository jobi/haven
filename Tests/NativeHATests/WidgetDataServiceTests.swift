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
    
    func testMultiChoiceRemoteAndSelectMapping() {
        let harmonyEntity = HAEntityState(
            entityId: "remote.living_room_harmony",
            state: "on",
            attributes: [
                "friendly_name": AnyCodable("Living Room Harmony"),
                "activity_list": AnyCodable([AnyCodable("Watch TV"), AnyCodable("Apple TV"), AnyCodable("Play PS5")]),
                "current_activity": AnyCodable("Apple TV")
            ]
        )
        let snapshot = WidgetEntitySnapshot(from: harmonyEntity, serverId: "home")
        XCTAssertTrue(snapshot.hasOptions)
        XCTAssertEqual(snapshot.options, ["Watch TV", "Apple TV", "Play PS5"])
        XCTAssertEqual(snapshot.currentOption, "Apple TV")
        XCTAssertEqual(snapshot.formattedState, "Apple TV")
        XCTAssertTrue(snapshot.isActive)
        
        let turnOn = WidgetDataService.optionServiceCall(for: "remote", option: "Watch TV")
        XCTAssertEqual(turnOn.domain, "remote")
        XCTAssertEqual(turnOn.service, "turn_on")
        XCTAssertEqual(turnOn.serviceData?["activity"]?.stringValue, "Watch TV")
        
        let powerOff = WidgetDataService.optionServiceCall(for: "remote", option: "PowerOff")
        XCTAssertEqual(powerOff.domain, "remote")
        XCTAssertEqual(powerOff.service, "turn_off")
        XCTAssertNil(powerOff.serviceData)
        
        let selectOpt = WidgetDataService.optionServiceCall(for: "input_select", option: "Evening")
        XCTAssertEqual(selectOpt.domain, "input_select")
        XCTAssertEqual(selectOpt.service, "select_option")
        XCTAssertEqual(selectOpt.serviceData?["option"]?.stringValue, "Evening")
    }
    
    func testClimateSnapshotExtraction() {
        let climate = HAEntityState(
            entityId: "climate.living_room",
            state: "heat",
            attributes: [
                "friendly_name": AnyCodable("Living Room"),
                "current_temperature": AnyCodable(70.5),
                "temperature": AnyCodable(72.0),
                "hvac_action": AnyCodable("heating"),
                "hvac_modes": AnyCodable([AnyCodable("off"), AnyCodable("heat"), AnyCodable("cool"), AnyCodable("heat_cool")])
            ]
        )
        let snap = WidgetEntitySnapshot(from: climate, serverId: "home")
        XCTAssertEqual(snap.currentTemperature, 70.5)
        XCTAssertEqual(snap.targetTemperature, 72.0)
        XCTAssertEqual(snap.hvacAction, "heating")
        XCTAssertEqual(snap.hvacModes, ["off", "heat", "cool", "heat_cool"])
        XCTAssertEqual(snap.effectiveTemperatureStep, 1.0)
    }
    
    func testMediaPlayerSnapshotExtraction() {
        let player = HAEntityState(
            entityId: "media_player.living_room_sonos",
            state: "playing",
            attributes: [
                "friendly_name": AnyCodable("Living Room Sonos"),
                "media_title": AnyCodable("Midnight City"),
                "media_artist": AnyCodable("M83"),
                "entity_picture": AnyCodable("/api/media_player_proxy/media_player.living_room_sonos?token=abc"),
                "volume_level": AnyCodable(0.45),
                "is_volume_muted": AnyCodable(false)
            ]
        )
        let snap = WidgetEntitySnapshot(from: player, serverId: "home")
        XCTAssertEqual(snap.mediaTitle, "Midnight City")
        XCTAssertEqual(snap.mediaArtist, "M83")
        XCTAssertEqual(snap.entityPicture, "/api/media_player_proxy/media_player.living_room_sonos?token=abc")
        XCTAssertEqual(snap.volumeLevel, 0.45)
        XCTAssertEqual(snap.isVolumeMuted, false)
        XCTAssertTrue(snap.isActive)
    }
}
