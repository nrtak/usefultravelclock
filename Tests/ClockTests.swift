import XCTest
@testable import UsefulTravelClock

final class ClockTests: XCTestCase {
    func testRepeatedHourPoliciesDifferByOneHour() throws {
        let first = try XCTUnwrap(TimeEngine.fromZonedInput(day: "2026-11-01", time: "01:30", timeZoneID: "America/New_York", repeatedTimePolicy: .first))
        let last = try XCTUnwrap(TimeEngine.fromZonedInput(day: "2026-11-01", time: "01:30", timeZoneID: "America/New_York", repeatedTimePolicy: .last))
        XCTAssertEqual(last.timeIntervalSince(first), 3600)
        XCTAssertEqual(TimeEngine.toZonedInput(first, timeZoneID: "America/New_York").time, "01:30")
        XCTAssertEqual(TimeEngine.toZonedInput(last, timeZoneID: "America/New_York").time, "01:30")
    }
    func testDateLineMidnightAndFractionalOffsetRoundTrips() throws {
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-01T10:00:00Z"))
        XCTAssertEqual(TimeEngine.toZonedInput(instant, timeZoneID: "Pacific/Kiritimati").day, "2026-01-02")
        XCTAssertEqual(TimeEngine.toZonedInput(instant, timeZoneID: "Pacific/Honolulu").day, "2026-01-01")
        for zone in ["Asia/Kathmandu", "Australia/Adelaide", "Pacific/Chatham", "Pacific/Kiritimati"] {
            let local = TimeEngine.toZonedInput(instant, timeZoneID: zone)
            XCTAssertEqual(TimeEngine.fromZonedInput(day: local.day, time: local.time, timeZoneID: zone), instant)
        }
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-01-01", time: "24:00", timeZoneID: "UTC"))
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-01-01", time: "12:60", timeZoneID: "UTC"))
    }
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
