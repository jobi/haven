import XCTest
@testable import NativeHACore

final class AuthAndConfigTests: XCTestCase {
    
    func testServerURLNormalization() {
        // Missing scheme
        let url1 = ServerConfig.normalizeURLString("192.168.1.50:8123")
        XCTAssertEqual(url1?.absoluteString, "http://192.168.1.50:8123")
        
        // Trailing slash
        let url2 = ServerConfig.normalizeURLString("https://myha.duckdns.org:8123/")
        XCTAssertEqual(url2?.absoluteString, "https://myha.duckdns.org:8123")
        
        // Multiple trailing slashes and spaces
        let url3 = ServerConfig.normalizeURLString("  https://myha.duckdns.org:8123///  ")
        XCTAssertEqual(url3?.absoluteString, "https://myha.duckdns.org:8123")
    }
    
    func testAuthTokensExpiration() {
        let freshTokens = AuthTokens(
            accessToken: "token_123",
            refreshToken: "refresh_123",
            expiresIn: 1800,
            createdAt: Date()
        )
        XCTAssertFalse(freshTokens.isExpired)
        
        let expiredTokens = AuthTokens(
            accessToken: "token_123",
            refreshToken: "refresh_123",
            expiresIn: 1800,
            createdAt: Date().addingTimeInterval(-2000)
        )
        XCTAssertTrue(expiredTokens.isExpired)
    }
    
    func testWebSocketURLConstruction() {
        let serverURL1 = URL(string: "https://coruscant.dingo-acoustic.ts.net")!
        var comp1 = URLComponents(url: serverURL1, resolvingAgainstBaseURL: true)!
        comp1.scheme = "wss"
        var basePath1 = comp1.path
        while basePath1.hasSuffix("/") { basePath1.removeLast() }
        if !basePath1.hasPrefix("/") { basePath1 = "/" + basePath1 }
        comp1.path = (basePath1 == "/" ? "" : basePath1) + "/api/websocket"
        XCTAssertEqual(comp1.url?.absoluteString, "wss://coruscant.dingo-acoustic.ts.net/api/websocket")
        
        let serverURL2 = URL(string: "http://192.168.1.50:8123/")!
        var comp2 = URLComponents(url: serverURL2, resolvingAgainstBaseURL: true)!
        comp2.scheme = "ws"
        var basePath2 = comp2.path
        while basePath2.hasSuffix("/") { basePath2.removeLast() }
        if !basePath2.hasPrefix("/") { basePath2 = "/" + basePath2 }
        comp2.path = (basePath2 == "/" ? "" : basePath2) + "/api/websocket"
        XCTAssertEqual(comp2.url?.absoluteString, "ws://192.168.1.50:8123/api/websocket")
    }
}
