import XCTest
@testable import NativeHACore

final class HistoryServiceTests: XCTestCase {
    
    func testHistoryLastPointMatchesCurrentValueSmoothly() async {
        let currentVal = 72.4
        let points = await HistoryService.shared.fetchHistory(
            serverURL: nil,
            token: nil,
            entityId: "sensor.living_room_temperature",
            currentValue: currentVal,
            hours: 24
        )
        
        XCTAssertFalse(points.isEmpty)
        guard let lastPoint = points.last else {
            XCTFail("No points returned")
            return
        }
        
        // The last point must match currentValue
        XCTAssertEqual(lastPoint.value, currentVal, accuracy: 0.05)
        
        // The second to last point must be close (no sharp artificial cliff)
        if points.count >= 2 {
            let secondToLast = points[points.count - 2]
            XCTAssertLessThan(abs(lastPoint.value - secondToLast.value), 2.5, "Curve should be smooth near the end, no sudden spike")
        }
    }
    
    func testHistoryZoomConsistencyAcrossTimeRanges() async {
        let currentVal = 68.5
        let entityId = "sensor.living_room_temperature"
        
        let p24 = await HistoryService.shared.fetchHistory(
            serverURL: nil,
            token: nil,
            entityId: entityId,
            currentValue: currentVal,
            hours: 24
        )
        
        let p12 = await HistoryService.shared.fetchHistory(
            serverURL: nil,
            token: nil,
            entityId: entityId,
            currentValue: currentVal,
            hours: 12
        )
        
        let p6 = await HistoryService.shared.fetchHistory(
            serverURL: nil,
            token: nil,
            entityId: entityId,
            currentValue: currentVal,
            hours: 6
        )
        
        // Check that at ~3 hours ago, the values in 24h, 12h, and 6h are consistent
        let targetDate = Date().addingTimeInterval(-3 * 3600)
        
        let val24 = p24.min(by: { abs($0.timestamp.timeIntervalSince(targetDate)) < abs($1.timestamp.timeIntervalSince(targetDate)) })?.value
        let val12 = p12.min(by: { abs($0.timestamp.timeIntervalSince(targetDate)) < abs($1.timestamp.timeIntervalSince(targetDate)) })?.value
        let val6 = p6.min(by: { abs($0.timestamp.timeIntervalSince(targetDate)) < abs($1.timestamp.timeIntervalSince(targetDate)) })?.value
        
        XCTAssertNotNil(val24)
        XCTAssertNotNil(val12)
        XCTAssertNotNil(val6)
        
        // Values at the same timestamp across zoom levels must be consistent
        XCTAssertEqual(val24!, val12!, accuracy: 1.0)
        XCTAssertEqual(val12!, val6!, accuracy: 1.0)
    }
    
    func testDistinctCurvesForDifferentEntities() async {
        let pTemp = await HistoryService.shared.fetchHistory(
            serverURL: nil,
            token: nil,
            entityId: "sensor.living_room_temperature",
            currentValue: 72.0,
            hours: 24
        )
        
        let pHumidity = await HistoryService.shared.fetchHistory(
            serverURL: nil,
            token: nil,
            entityId: "sensor.living_room_humidity",
            currentValue: 45.0,
            hours: 24
        )
        
        // Min / max ranges and variance should differ
        let tempMin = pTemp.map(\.value).min() ?? 0
        let humidityMin = pHumidity.map(\.value).min() ?? 0
        
        XCTAssertNotEqual(tempMin, humidityMin)
    }
}
