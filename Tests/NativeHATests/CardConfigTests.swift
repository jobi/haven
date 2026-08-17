import XCTest
@testable import NativeHACore

final class CardConfigTests: XCTestCase {
    
    func testTileCardConfigDecoding() throws {
        let json = """
        {
          "type": "tile",
          "entity": "light.kitchen",
          "name": "Kitchen Lights",
          "icon": "mdi:ceiling-light",
          "color": "#FFC107",
          "tap_action": {
            "action": "toggle"
          },
          "features": [
            { "type": "light-brightness" }
          ]
        }
        """.data(using: .utf8)!
        
        let anyCard = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        XCTAssertEqual(anyCard.type, "tile")
        
        let tileConfig = try anyCard.decode(TileCardConfig.self)
        XCTAssertEqual(tileConfig.entity, "light.kitchen")
        XCTAssertEqual(tileConfig.name, "Kitchen Lights")
        XCTAssertEqual(tileConfig.color, "#FFC107")
        XCTAssertEqual(tileConfig.tapAction?.action, "toggle")
        XCTAssertEqual(tileConfig.features?.first?.type, "light-brightness")
    }
    
    func testEntitiesCardConfigDecoding() throws {
        let json = """
        {
          "type": "entities",
          "title": "Living Room",
          "icon": "mdi:sofa",
          "entities": [
            "light.living_room",
            {
              "entity": "switch.heater",
              "name": "Space Heater",
              "icon": "mdi:radiator"
            }
          ]
        }
        """.data(using: .utf8)!
        
        let anyCard = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        let entitiesConfig = try anyCard.decode(EntitiesCardConfig.self)
        
        XCTAssertEqual(entitiesConfig.title, "Living Room")
        XCTAssertEqual(entitiesConfig.icon, "mdi:sofa")
        XCTAssertEqual(entitiesConfig.entities.count, 2)
        XCTAssertEqual(entitiesConfig.entities[0].entity, "light.living_room")
        XCTAssertEqual(entitiesConfig.entities[1].entity, "switch.heater")
        XCTAssertEqual(entitiesConfig.entities[1].name, "Space Heater")
        XCTAssertEqual(entitiesConfig.entities[1].icon, "mdi:radiator")
    }
    
    func testButtonCardConfigDecoding() throws {
        let json = """
        {
          "type": "button",
          "entity": "scene.good_night",
          "name": "Good Night",
          "icon": "mdi:bed",
          "show_name": true,
          "show_state": false,
          "tap_action": {
            "action": "call-service",
            "service": "scene.turn_on"
          }
        }
        """.data(using: .utf8)!
        
        let anyCard = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        let buttonConfig = try anyCard.decode(ButtonCardConfig.self)
        
        XCTAssertEqual(buttonConfig.entity, "scene.good_night")
        XCTAssertEqual(buttonConfig.name, "Good Night")
        XCTAssertEqual(buttonConfig.showName, true)
        XCTAssertEqual(buttonConfig.showState, false)
        XCTAssertEqual(buttonConfig.tapAction?.action, "call-service")
        XCTAssertEqual(buttonConfig.tapAction?.service, "scene.turn_on")
    }
    
    func testMarkdownCardConfigDecoding() throws {
        let json = """
        {
          "type": "markdown",
          "title": "Notes",
          "content": "**Welcome** to *NativeHA*!"
        }
        """.data(using: .utf8)!
        
        let anyCard = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        let markdownConfig = try anyCard.decode(MarkdownCardConfig.self)
        
        XCTAssertEqual(markdownConfig.title, "Notes")
        XCTAssertEqual(markdownConfig.content, "**Welcome** to *NativeHA*!")
    }
    
    func testMediaControlCardConfigDecoding() throws {
        let json = """
        {
          "type": "media-control",
          "entity": "media_player.living_room_tv",
          "name": "Living Room TV"
        }
        """.data(using: .utf8)!
        
        let anyCard = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        let mediaConfig = try anyCard.decode(MediaControlCardConfig.self)
        
        XCTAssertEqual(mediaConfig.type, "media-control")
        XCTAssertEqual(mediaConfig.entity, "media_player.living_room_tv")
        XCTAssertEqual(mediaConfig.name, "Living Room TV")
    }
}
