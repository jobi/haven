import XCTest
@testable import NativeHACore

final class WebSocketLifecycleTests: XCTestCase {

    func testPauseForBackgroundAndResumeFromBackground() async {
        let client = HAWebSocketClient()
        let server = ServerConfig(
            id: "test-server",
            name: "Test HA",
            url: URL(string: "http://127.0.0.1:18123")!
        )

        await client.connect(server: server) {
            "dummy-token"
        }

        await client.pauseForBackground()
        let pausedState = await client.state
        XCTAssertEqual(pausedState, .disconnected)

        await client.resumeFromBackground()
        let resumedState = await client.state
        XCTAssertNotEqual(resumedState, .disconnected, "Resuming from background should immediately initiate reconnection")

        await client.disconnect()
    }

    func testIntentionalDisconnectPreventsResumeFromBackground() async {
        let client = HAWebSocketClient()
        let server = ServerConfig(
            id: "test-server",
            name: "Test HA",
            url: URL(string: "http://127.0.0.1:18123")!
        )

        await client.connect(server: server) {
            "dummy-token"
        }

        await client.disconnect()
        let disconnectedState = await client.state
        XCTAssertEqual(disconnectedState, .disconnected)

        await client.resumeFromBackground()
        let stateAfterResume = await client.state
        XCTAssertEqual(stateAfterResume, .disconnected, "Intentional disconnect should not auto-reconnect on foreground")
    }
}
