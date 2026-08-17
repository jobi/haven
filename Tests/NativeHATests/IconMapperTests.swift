import XCTest
@testable import NativeHACore

final class IconMapperTests: XCTestCase {
    
    func testIconMapping() {
        // Direct MDI icons
        XCTAssertEqual(IconMapper.sfSymbol(for: "mdi:lightbulb", isActive: false), "lightbulb")
        XCTAssertEqual(IconMapper.sfSymbol(for: "mdi:lightbulb", isActive: true), "lightbulb.fill")
        XCTAssertEqual(IconMapper.sfSymbol(for: "mdi:fan", isActive: false), "fan")
        XCTAssertEqual(IconMapper.sfSymbol(for: "mdi:fan", isActive: true), "fan.fill")
        XCTAssertEqual(IconMapper.sfSymbol(for: "mdi:lock", isActive: false), "lock.fill")
        XCTAssertEqual(IconMapper.sfSymbol(for: "mdi:lock", isActive: true), "lock.open.fill")
        
        // Domain fallback when icon is nil or unmapped
        XCTAssertEqual(IconMapper.sfSymbol(for: nil, domain: "climate", isActive: false), "thermometer.medium")
        XCTAssertEqual(IconMapper.sfSymbol(for: nil, domain: "climate", isActive: true), "thermometer.sun.fill")
        XCTAssertEqual(IconMapper.sfSymbol(for: nil, domain: "vacuum", isActive: false), "circle.grid.cross")
    }
}
