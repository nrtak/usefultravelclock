import XCTest
@testable import UsefulTravelClock

final class ClockTests: XCTestCase {
    func testDSTGapAndRepeatedTime() {
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-03-08", time: "02:30", timeZoneID: "America/New_York"))
        let repeated = TimeEngine.fromZonedInput(day: "2026-11-01", time: "01:30", timeZoneID: "America/New_York")
        XCTAssertEqual(repeated, ISO8601DateFormatter().date(from: "2026-11-01T05:30:00Z"))
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-02-30", time: "12:00", timeZoneID: "UTC"))
    }
    func testFractionalOffsetsAndAirportSearch() {
        let date = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        XCTAssertEqual(TimeEngine.timeDifferenceMinutes(date, timeZoneID: "Asia/Kathmandu", homeTimeZoneID: "America/Los_Angeles"), 825)
        XCTAssertEqual(CitySearch.search("JFK", in: cities).first?.id, "nyc")
    }
    @MainActor func testSettingsPersistAcrossLaunches() {
        let suite = "test." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.theme = .dark
        store.homeMode = .manual
        store.homeCityID = "lon"
        store.cityIDs = ["lon", "nyc"]
        let restored = UsefulTravelClockStore(defaults: defaults)
        XCTAssertEqual(restored.theme, .dark)
        XCTAssertEqual(restored.homeMode, .manual)
        XCTAssertEqual(restored.homeCityID, "lon")
        XCTAssertEqual(restored.cityIDs, ["lon", "nyc"])
    }
}
