import XCTest
@testable import NativeHACore

final class LayoutEngineTests: XCTestCase {
    
    func testBreakpointCalculations() {
        // iPhone Portrait (width: 390) -> 1 column
        let colIphone = SectionLayoutEngine.calculateColumnCount(for: 390)
        XCTAssertEqual(colIphone, 1)
        
        // iPad Portrait (width: 820) -> 2 columns
        let colIpadPort = SectionLayoutEngine.calculateColumnCount(for: 820)
        XCTAssertEqual(colIpadPort, 2)
        
        // iPad Landscape / Mac (width: 1200) -> 3 columns
        let colIpadLand = SectionLayoutEngine.calculateColumnCount(for: 1200)
        XCTAssertEqual(colIpadLand, 3)
        
        // Large Display (width: 1800) -> 4 columns
        let colWide = SectionLayoutEngine.calculateColumnCount(for: 1800)
        XCTAssertEqual(colWide, 4)
        
        // Respects maxColumns clamp
        let colClamped = SectionLayoutEngine.calculateColumnCount(for: 1800, maxAllowed: 2)
        XCTAssertEqual(colClamped, 2)
    }
}
