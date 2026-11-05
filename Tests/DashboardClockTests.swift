import XCTest
@testable import UsefulTravelClock

final class DashboardClockTests: XCTestCase {
    func testCityOffsetLabelsPreserveDirectionMinutesAndSameZone() {
        XCTAssertEqual(TimeEngine.formatCityOffset(17 * 60), "+17 hr")
        XCTAssertEqual(TimeEngine.formatCityOffset(-9 * 60), "-9 hr")
        XCTAssertEqual(TimeEngine.formatCityOffset(0), "0 hr")
        XCTAssertEqual(TimeEngine.formatCityOffset(345), "+5 hr 45 min")
        XCTAssertEqual(TimeEngine.formatCityOffset(-210), "-3 hr 30 min")
        XCTAssertEqual(TimeEngine.formatCityOffset(30), "+30 min")
        XCTAssertEqual(TimeEngine.formatCityOffset(-45), "-45 min")
    }

    func testCityOffsetsFollowHomeDaylightSavingAtTheComparedInstant() throws {
        let formatter = ISO8601DateFormatter()
        let winter = try XCTUnwrap(formatter.date(from: "2026-11-04T12:00:00Z"))
        let summer = try XCTUnwrap(formatter.date(from: "2026-07-04T12:00:00Z"))
        let tokyoWinter = TimeEngine.timeDifferenceMinutes(winter, timeZoneID: "Asia/Tokyo", homeTimeZoneID: "America/Los_Angeles")
        let tokyoSummer = TimeEngine.timeDifferenceMinutes(summer, timeZoneID: "Asia/Tokyo", homeTimeZoneID: "America/Los_Angeles")
        XCTAssertEqual(TimeEngine.formatCityOffset(tokyoWinter), "+17 hr")
        XCTAssertEqual(TimeEngine.formatCityOffset(tokyoSummer), "+16 hr")
        XCTAssertEqual(TimeEngine.formatCityOffset(TimeEngine.timeDifferenceMinutes(winter, timeZoneID: "America/Los_Angeles", homeTimeZoneID: "Asia/Tokyo")), "-17 hr")
        XCTAssertEqual(TimeEngine.formatCityOffset(TimeEngine.timeDifferenceMinutes(winter, timeZoneID: "Asia/Kathmandu", homeTimeZoneID: "America/Los_Angeles")), "+13 hr 45 min")
    }

    @MainActor func testAllSavedCitiesAreVisibleAndOnlyActiveManualHomeIsExcluded() {
        let suite = "comparison." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.cityIDs = ["nyc", "lon", "tyo", "mel", "sfo", "dxb", "sin", "ber", "syd", "mil"]
        store.homeCityID = "nyc"
        store.homeMode = .manual
        XCTAssertEqual(store.comparisonCities(destinationID: "tyo").map(\.id), ["lon", "mel", "sfo", "dxb", "sin", "ber", "syd", "mil"])
        store.homeMode = .automatic
        XCTAssertEqual(store.comparisonCities(destinationID: "tyo").map(\.id), ["nyc", "lon", "mel", "sfo", "dxb", "sin", "ber", "syd", "mil"])
    }

    @MainActor func testReplacementCannotHideCityBehindPrimaryClocks() {
        let suite = "comparison." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.homeMode = .manual; store.homeCityID = "nyc"
        store.cityIDs = ["lon", "mel"] // Primary clocks need not be in the saved list.
        XCTAssertFalse(store.replaceComparisonCity("lon", with: "tyo", destinationID: "tyo"))
        XCTAssertFalse(store.replaceComparisonCity("lon", with: "nyc", destinationID: "tyo"))
        XCTAssertFalse(store.replaceComparisonCity("lon", with: "mel", destinationID: "tyo"))
        XCTAssertEqual(store.cityIDs, ["lon", "mel"])
        XCTAssertTrue(store.replaceComparisonCity("lon", with: "sfo", destinationID: "tyo"))
        XCTAssertEqual(store.comparisonCities(destinationID: "tyo").map(\.id), ["sfo", "mel"])
    }

    @MainActor func testReorderingPreservesPrimaryPositionsAndSupportsUndo() {
        let suite = "comparison." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.homeMode = .manual; store.homeCityID = "nyc"
        store.cityIDs = ["nyc", "lon", "tyo", "mel", "sfo"]
        XCTAssertFalse(store.moveComparisonCity("nyc", to: "mel", destinationID: "tyo"))
        XCTAssertFalse(store.moveComparisonCity("lon", to: "tyo", destinationID: "tyo"))
        XCTAssertTrue(store.moveComparisonCity("lon", to: "sfo", destinationID: "tyo"))
        XCTAssertEqual(store.cityIDs, ["nyc", "mel", "tyo", "sfo", "lon"])
        store.undoLastEdit()
        XCTAssertEqual(store.cityIDs, ["nyc", "lon", "tyo", "mel", "sfo"])
    }

    @MainActor func testRestoredCitiesDiscardDuplicatesAndInvalidIDsBeforeLimit() throws {
        let suite = "comparison." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let valid = ["nyc", "lon", "tyo", "mel", "sfo", "dxb", "sin", "ber", "syd", "mil"]
        defaults.set(try JSONEncoder().encode(["invalid"] + Array(repeating: "nyc", count: 5) + valid), forKey: "usefultravelclock-cities")
        let store = UsefulTravelClockStore(defaults: defaults)
        XCTAssertEqual(store.cityIDs, valid)
        XCTAssertEqual(store.selectedCities.count, 10)
    }
}
