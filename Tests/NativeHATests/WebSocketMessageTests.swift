import XCTest
@testable import NativeHACore

final class WebSocketMessageTests: XCTestCase {
    
    func testOutgoingCommandSerialization() throws {
        let cmd = HAOutgoingCommand(
            id: 42,
            type: "call_service",
            domain: "light",
            service: "turn_on",
            target: ["entity_id": AnyCodable("light.living_room")],
            serviceData: ["brightness": AnyCodable(255)]
        )
        
        let data = try JSONEncoder().encode(cmd)
        let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        XCTAssertEqual(jsonDict?["id"] as? Int, 42)
        XCTAssertEqual(jsonDict?["type"] as? String, "call_service")
        XCTAssertEqual(jsonDict?["domain"] as? String, "light")
        XCTAssertEqual(jsonDict?["service"] as? String, "turn_on")
        
        let target = jsonDict?["target"] as? [String: Any]
        XCTAssertEqual(target?["entity_id"] as? String, "light.living_room")
    }
    
    func testIncomingMessageParsing() throws {
        let json = """
        {
          "id": 1,
          "type": "result",
          "success": true,
          "result": {
            "title": "Home Assistant"
          }
        }
        """.data(using: .utf8)!
        
        let msg = try JSONDecoder().decode(HAIncomingMessage.self, from: json)
        XCTAssertEqual(msg.id, 1)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.success, true)
        XCTAssertEqual(msg.result?.dictionaryValue?["title"]?.stringValue, "Home Assistant")
    }
}
