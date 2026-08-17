import XCTest
@testable import NativeHACore

@MainActor
final class VisibilityTests: XCTestCase {
    
    func testStateVisibility() {
        let store = EntityStore()
        
        // Initial setup
        let dumpJSON = """
        {
          "a": {
            "input_boolean.night_mode": {
              "s": "off",
              "a": {}
            },
            "sensor.temperature": {
              "s": "22.5",
              "a": {}
            }
          }
        }
        """.data(using: .utf8)!
        let dump = try! JSONDecoder().decode(AnyCodable.self, from: dumpJSON)
        store.processEntityEvent(dump)
        
        // 1. Condition: input_boolean.night_mode == "on"
        let nightModeCondition: [AnyCodable] = [
            AnyCodable([
                "condition": AnyCodable("state"),
                "entity": AnyCodable("input_boolean.night_mode"),
                "state": AnyCodable("on")
            ])
        ]
        
        // Should be hidden when night_mode is "off"
        XCTAssertFalse(VisibilityEvaluator.isVisible(visibility: nightModeCondition, entityStore: store))
        
        // Update night_mode to "on"
        let deltaJSON = """
        {
          "c": {
            "input_boolean.night_mode": {
              "+": {
                "s": "on"
              }
            }
          }
        }
        """.data(using: .utf8)!
        let delta = try! JSONDecoder().decode(AnyCodable.self, from: deltaJSON)
        store.processEntityEvent(delta)
        
        // Now should be visible
        XCTAssertTrue(VisibilityEvaluator.isVisible(visibility: nightModeCondition, entityStore: store))
    }
    
    func testNumericStateVisibility() {
        let store = EntityStore()
        let dumpJSON = """
        {
          "a": {
            "sensor.temperature": {
              "s": "24.0",
              "a": {}
            }
          }
        }
        """.data(using: .utf8)!
        let dump = try! JSONDecoder().decode(AnyCodable.self, from: dumpJSON)
        store.processEntityEvent(dump)
        
        let tempCondition: [AnyCodable] = [
            AnyCodable([
                "condition": AnyCodable("numeric_state"),
                "entity": AnyCodable("sensor.temperature"),
                "above": AnyCodable(20.0),
                "below": AnyCodable(30.0)
            ])
        ]
        
        XCTAssertTrue(VisibilityEvaluator.isVisible(visibility: tempCondition, entityStore: store))
    }
    
    func testEmptyVisibilityDefaultsToVisible() {
        let store = EntityStore()
        XCTAssertTrue(VisibilityEvaluator.isVisible(visibility: nil, entityStore: store))
        XCTAssertTrue(VisibilityEvaluator.isVisible(visibility: [], entityStore: store))
    }
}
