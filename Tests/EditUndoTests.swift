import XCTest
@testable import UsefulTravelClock

final class EditUndoTests: XCTestCase {
    @MainActor func testRemoveUndoRestoresAllCityDetailsAndPosition() {
        let suite = "undo." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.cityIDs = ["nyc", "lon", "tyo"]
        store.nicknames["lon"] = "Friend"
        store.toggleFavorite("lon")
        store.removeCity("lon")
        XCTAssertFalse(store.cityIDs.contains("lon"))
        store.undoLastEdit()
        XCTAssertEqual(store.cityIDs, ["nyc", "lon", "tyo"])
        XCTAssertEqual(store.nicknames["lon"], "Friend")
        XCTAssertEqual(store.favoriteIDs, ["lon"])
        let restored = UsefulTravelClockStore(defaults: defaults)
        XCTAssertEqual(restored.cityIDs, store.cityIDs)
        XCTAssertEqual(restored.nicknames, store.nicknames)
        XCTAssertFalse(restored.canUndo) // Undo history belongs to this session.
    }

    @MainActor func testReplaceAndReorderUndoAreSingleActions() {
        let suite = "undo." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        store.cityIDs = ["nyc", "lon"]
        store.homeCityID = "nyc"
        store.nicknames["nyc"] = "Home"
        store.toggleFavorite("nyc")
        XCTAssertTrue(store.replaceCity("nyc", with: "tyo"))
        store.undoLastEdit()
        XCTAssertEqual(store.cityIDs, ["nyc", "lon"])
        XCTAssertEqual(store.homeCityID, "nyc")
        XCTAssertEqual(store.favoriteIDs, ["nyc"])
        XCTAssertEqual(store.nicknames["nyc"], "Home")
        store.toggleFavorite("nyc")
        store.sortOrder = .name
        store.moveCity("nyc", to: "lon")
        XCTAssertEqual(store.sortOrder, .custom)
        store.undoLastEdit()
        XCTAssertEqual(store.sortOrder, .name)
        XCTAssertEqual(store.cityIDs, ["nyc", "lon"])
    }

    @MainActor func testSettingsAndAddCanBeUndoneWithoutCreatingRedoHistory() {
        let suite = "undo." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: defaults)
        XCTAssertFalse(store.canUndo)
        store.use24 = true
        store.theme = .dark
        store.undoLastEdit()
        XCTAssertEqual(store.theme, .light)
        XCTAssertTrue(store.use24)
        store.undoLastEdit()
        XCTAssertFalse(store.use24)
        XCTAssertFalse(store.canUndo)
        let original = store.cityIDs
        let added = store.allCities.first { !original.contains($0.id) }!.id
        store.toggleCity(added)
        store.undoLastEdit()
        XCTAssertEqual(store.cityIDs, original)
        XCTAssertFalse(store.canUndo)
    }
}
