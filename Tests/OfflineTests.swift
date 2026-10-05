import XCTest
@testable import UsefulTravelClock

final class OfflineTests: XCTestCase {
    @MainActor
    func testDisconnectedRefreshKeepsSavedRatesAfterRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("rates.json")
        let snapshot = RateSnapshot(fetchedAt: Date(timeIntervalSince1970: 1000), rows: [Rate(date: "2026-10-02", base: "USD", quote: "JPY", rate: 150)])
        try JSONEncoder().encode(snapshot).write(to: url)
        let suite = "OfflineTests-" + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let store = ConverterStore(preferences: preferences, cacheURL: url, service: NeverFetchRates(), isOffline: { true })
        store.source = "USD"; store.target = "JPY"; store.amount = "10"
        await store.refresh(force: true)
        XCTAssertFalse(store.isLoading)
        XCTAssertTrue(store.updateFailed)
        XCTAssertEqual(store.value(for: "JPY"), 1500)
        XCTAssertEqual(store.snapshot?.fetchedAt, snapshot.fetchedAt)
        XCTAssertEqual(store.savedDraft()?.ratesCheckedAt, snapshot.fetchedAt)
    }
    @MainActor
    func testOfflineWeatherLocationSearchIgnoresCaseAccentsAndDuplicates() {
        let place = WeatherLocation(name: "São Paulo", latitude: -23.55, longitude: -46.63)
        let other = WeatherLocation(name: "Tokyo", latitude: 35.68, longitude: 139.76)
        XCTAssertEqual(TripWeatherStore.savedLocations(matching: "  SAO  ", in: [place, place, other]).map(\.id), [place.id])
        XCTAssertTrue(TripWeatherStore.savedLocations(matching: "London", in: [place, other]).isEmpty)
    }
    func testOfflineHelpAndBundledRatesAreIncluded() throws {
        let video = try XCTUnwrap(Bundle.main.url(forResource: "Trip_Info_Quick_Tour", withExtension: "mp4"))
        XCTAssertGreaterThan(try Data(contentsOf: video).count, 1000)
        let ratesURL = try XCTUnwrap(Bundle.main.url(forResource: "BundledRates", withExtension: "json"))
        let rows = try JSONDecoder().decode([Rate].self, from: Data(contentsOf: ratesURL))
        XCTAssertGreaterThan(rows.count, 150)
        XCTAssertTrue(rows.allSatisfy { $0.base == "USD" && $0.rate > 0 && RateSnapshot.validDate($0.date) != nil })
        let snapshot = RateSnapshot(fetchedAt: Date(), rows: rows)
        XCTAssertNotNil(snapshot.multiplier(from: "USD", to: "EUR"))
        XCTAssertNotNil(snapshot.multiplier(from: "JPY", to: "GBP"))
    }
}
private struct NeverFetchRates: RateService {
    func fetch() async throws -> RateSnapshot {
        XCTFail("An offline refresh must not request network rates")
        throw URLError(.notConnectedToInternet)
    }
}
