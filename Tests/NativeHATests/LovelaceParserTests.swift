import XCTest
@testable import NativeHACore

final class LovelaceParserTests: XCTestCase {
    
    func testDecodeFullLovelaceConfig() throws {
        let data = MockDataFixtures.sampleLovelaceConfigJSON.data(using: .utf8)!
        let config = try JSONDecoder().decode(LovelaceConfig.self, from: data)
        
        XCTAssertEqual(config.title, "Home")
        XCTAssertEqual(config.views.count, 2)
        
        let sectionView = try XCTUnwrap(config.views.first(where: { $0.isSectionsType }))
        XCTAssertEqual(sectionView.title, "Living Room")
        XCTAssertEqual(sectionView.path, "living-room")
        XCTAssertEqual(sectionView.maxColumns, 3)
        XCTAssertEqual(sectionView.badges?.count, 2)
        XCTAssertEqual(sectionView.sections?.count, 3)
        
        // Check first section cards
        let lightingSection = sectionView.sections![0]
        XCTAssertEqual(lightingSection.title, "Lighting")
        XCTAssertEqual(lightingSection.cards.count, 3)
        
        // 1. Heading Card
        let headingCard = try lightingSection.cards[0].decode(HeadingCardConfig.self)
        XCTAssertEqual(headingCard.type, "heading")
        XCTAssertEqual(headingCard.heading, "Ceiling Lights")
        XCTAssertEqual(headingCard.headingStyle, "title")
        
        // 2. Tile Card with Brightness Feature
        let tileCard = try lightingSection.cards[1].decode(TileCardConfig.self)
        XCTAssertEqual(tileCard.type, "tile")
        XCTAssertEqual(tileCard.entity, "light.living_room_ceiling")
        XCTAssertEqual(tileCard.name, "Main Lights")
        XCTAssertEqual(tileCard.features?.count, 1)
        XCTAssertEqual(tileCard.features?.first?.type, "light-brightness")
        
        // 3. Gauge Card
        let climateSection = sectionView.sections![1]
        let gaugeCard = try climateSection.cards[0].decode(GaugeCardConfig.self)
        XCTAssertEqual(gaugeCard.type, "gauge")
        XCTAssertEqual(gaugeCard.entity, "sensor.indoor_temperature")
        XCTAssertEqual(gaugeCard.min, 10.0)
        XCTAssertEqual(gaugeCard.max, 35.0)
        XCTAssertEqual(gaugeCard.severity?["green"], 20.0)
        
        // 4. Custom/Unhandled Card Fallback
        let controlSection = sectionView.sections![2]
        let customCard = controlSection.cards[2]
        XCTAssertEqual(customCard.type, "custom:mushroom-chips-card")
    }
}
