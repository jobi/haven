import XCTest
@testable import NativeHACore

final class CameraStreamTests: XCTestCase {
    
    func testCameraEntityAttributes() {
        let attributes: [String: AnyCodable] = [
            "friendly_name": AnyCodable("Front Door Camera"),
            "frontend_stream_type": AnyCodable("hls"),
            "motion_detection": AnyCodable(true),
            "brand": AnyCodable("UniFi Protect"),
            "model_name": AnyCodable("G4 Doorbell Pro"),
            "entity_picture": AnyCodable("/api/camera_proxy/camera.front_door?token=xyz123")
        ]
        
        let entity = HAEntityState(
            entityId: "camera.front_door",
            state: "idle",
            attributes: attributes
        )
        
        XCTAssertEqual(entity.entityId, "camera.front_door")
        XCTAssertEqual(entity.domain, "camera")
        XCTAssertEqual(entity.friendlyName, "Front Door Camera")
        XCTAssertEqual(entity.attributes["frontend_stream_type"]?.stringValue, "hls")
        XCTAssertEqual(entity.attributes["motion_detection"]?.boolValue, true)
        XCTAssertEqual(entity.attributes["brand"]?.stringValue, "UniFi Protect")
        XCTAssertEqual(entity.attributes["model_name"]?.stringValue, "G4 Doorbell Pro")
        XCTAssertEqual(entity.attributes["entity_picture"]?.stringValue, "/api/camera_proxy/camera.front_door?token=xyz123")
    }
    
    func testCameraStreamURLResolution() {
        let serverURL = URL(string: "https://home.example.com")!
        let streamPath = "/api/hls/token_abc123/playlist.m3u8"
        
        let base = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = streamPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fullURLString = "\(base)/\(cleanPath)"
        
        let url = URL(string: fullURLString)
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://home.example.com/api/hls/token_abc123/playlist.m3u8")
    }
    
    @MainActor
    func testHAMJPEGStreamerInstantiation() {
        let streamer = HAMJPEGStreamer()
        XCTAssertFalse(streamer.isStreaming)
        XCTAssertFalse(streamer.isConnecting)
        XCTAssertNil(streamer.currentFrameData)
    }
}
