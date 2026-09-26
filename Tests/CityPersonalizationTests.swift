import XCTest
@testable import UsefulTravelClock

final class CityPersonalizationTests: XCTestCase {
    @MainActor func testSortingPinningAndPersistence() {
        let suite = "cities." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        XCTAssertEqual(store.sortOrder, .custom)
        store.cityIDs = ["tyo", "nyc", "lon"]
        store.nicknames["nyc"] = "Friend"
        store.sortOrder = .name
        XCTAssertEqual(store.orderedCities().map(\.id), ["lon", "nyc", "tyo"])
        store.toggleFavorite("tyo")
        XCTAssertEqual(store.orderedCities().map(\.id), ["tyo", "lon", "nyc"])
        store.sortOrder = .timeZone
        XCTAssertEqual(store.orderedCities(at: Date(timeIntervalSince1970: 1768478400)).map(\.id), ["tyo", "nyc", "lon"])
        store.sortOrder = .custom
        XCTAssertEqual(store.cityIDs, ["tyo", "nyc", "lon"])
        store.moveCity("lon", to: "nyc")
        XCTAssertEqual(store.cityIDs, ["tyo", "lon", "nyc"])
        store.moveCity("nyc", to: "tyo") // Cannot cross the pinned boundary.
        XCTAssertEqual(store.cityIDs, ["tyo", "lon", "nyc"])
        let restored = UsefulTravelClockStore(defaults: defaults)
        XCTAssertEqual(restored.favoriteIDs, ["tyo"])
        XCTAssertEqual(restored.nicknames["nyc"], "Friend")
        XCTAssertEqual(restored.cityIDs, store.cityIDs)
    }

    @MainActor func testReplacementAndRemoval() {
        let suite = "cities." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.cityIDs = ["nyc", "lon"]
        store.homeCityID = "nyc"
        store.nicknames["nyc"] = "Friend"
        store.toggleFavorite("nyc")
        XCTAssertFalse(store.replaceCity("nyc", with: "lon"))
        XCTAssertTrue(store.replaceCity("nyc", with: "tyo"))
        XCTAssertEqual(store.homeCityID, "tyo")
        XCTAssertEqual(store.nicknames["tyo"], "Friend")
        XCTAssertEqual(store.favoriteIDs, ["tyo"])
        store.removeCity("tyo")
        XCTAssertEqual(store.cityIDs, ["lon"])
        XCTAssertTrue(store.favoriteIDs.isEmpty)
        XCTAssertNil(store.nicknames["tyo"])
    }

    func testWidgetCountsAndIndependentPositions() {
        let available = ["a", "b", "c", "d", "e", "f", "g"]
        for count in 1...6 {
            let ids = WidgetCitySelection.resolve(Array(available.prefix(count)).map { Optional($0) }, available: available)
            XCTAssertEqual(ids.count, count)
            XCTAssertEqual(Set(ids).count, count)
        }
        XCTAssertEqual(WidgetCitySelection.resolve(["f", "c"], available: available), ["f", "c"])
        XCTAssertEqual(WidgetCitySelection.resolve([nil, "a", nil, "c", nil, "b"], available: available), ["a", "c", "b"])
        XCTAssertEqual(WidgetCitySelection.resolve(["missing"], available: available), [])
        XCTAssertEqual(WidgetCitySelection.resolve([nil, nil], available: available), [])
    }
}
