import XCTest
@testable import NativeHACore

@MainActor
final class ActionHandlerTests: XCTestCase {
    
    func testBadgeActionDecoding() throws {
        let json = """
        {
          "type": "badge",
          "entity": "input_boolean.night_mode",
          "tap_action": {
            "action": "toggle"
          },
          "hold_action": {
            "action": "more-info"
          }
        }
        """.data(using: .utf8)!
        
        let card = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        XCTAssertEqual(card.type, "badge")
        XCTAssertEqual(card.tapAction?.action, "toggle")
        XCTAssertEqual(card.holdAction?.action, "more-info")
    }
    
    func testPerformActionDecoding() throws {
        let json = """
        {
          "type": "badge",
          "entity": "input_boolean.night_mode",
          "tap_action": {
            "perform_action": "input_boolean.toggle",
            "target": {
              "entity_id": "input_boolean.night_mode"
            }
          }
        }
        """.data(using: .utf8)!
        
        let card = try JSONDecoder().decode(AnyCardConfig.self, from: json)
        XCTAssertEqual(card.tapAction?.performAction, "input_boolean.toggle")
        XCTAssertEqual(card.tapAction?.target?["entity_id"]?.stringValue, "input_boolean.night_mode")
    }
}
