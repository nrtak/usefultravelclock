import XCTest
@testable import UsefulTravelClock

final class DashboardClockTests: XCTestCase {
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
