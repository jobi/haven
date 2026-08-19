import XCTest
import CoreGraphics
@testable import NativeHACore

final class MDIIconTests: XCTestCase {
    
    func testSVGPathParserBasicCommands() {
        let svg = "M10 20 L20 20 H30 V40 C10 10 20 20 30 30 Z"
        let path = SVGPathParser.parse(svgPath: svg)
        XCTAssertNotNil(path, "SVGPathParser should parse standard SVG commands")
        XCTAssertFalse(path!.isEmpty, "Parsed CGPath should not be empty")
    }
    
    func testSVGPathParserArcs() {
        let svg = "M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2Z"
        let path = SVGPathParser.parse(svgPath: svg)
        XCTAssertNotNil(path, "SVGPathParser should parse elliptical arcs")
        XCTAssertFalse(path!.isEmpty, "Parsed circle arc path should not be empty")
    }
    
    func testMDIIconRepositoryLookup() {
        let repo = MDIIconRepository.shared
        
        let testIcons = [
            "home",
            "fireplace",
            "ceiling-light",
            "sofa",
            "television",
            "curtains",
            "weather-sunny",
            "lightbulb",
            "power",
            "fan",
            "lock"
        ]
        
        for name in testIcons {
            XCTAssertTrue(repo.hasIcon(name: name), "MDI repository should have icon: \(name)")
            let pathDirect = repo.path(for: name)
            XCTAssertNotNil(pathDirect, "Should return valid CGPath for \(name)")
            
            // With mdi: prefix
            let pathPrefixed = repo.path(for: "mdi:\(name)")
            XCTAssertNotNil(pathPrefixed, "Should return valid CGPath for mdi:\(name)")
        }
    }
    
    func testMDIIconRepositoryCaching() {
        let repo = MDIIconRepository.shared
        let path1 = repo.path(for: "mdi:fireplace")
        let path2 = repo.path(for: "fireplace")
        XCTAssertNotNil(path1)
        XCTAssertNotNil(path2)
        XCTAssertEqual(path1, path2, "Cached path reference should be returned for same icon")
    }
}
