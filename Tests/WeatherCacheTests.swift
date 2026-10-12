import XCTest
@testable import UsefulTravelClock

final class WeatherCacheTests: XCTestCase {
    @MainActor
    func testForecastFreshnessAndDiskFailureAreSeparateFromNetworkFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([1]).write(to: directory)
        let store = TripWeatherStore(directory: directory)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let place = WeatherLocation(name: "Tokyo", latitude: 35.68, longitude: 139.69, timeZoneIdentifier: "Asia/Tokyo")
        let forecast = CachedWeather(fetchedAt: now, observedAt: now, celsius: 20, high: 25, low: 15, condition: "Clear", symbol: "sun.max")
        store.storeForecast(forecast, for: place, manuallyRefreshed: true)
        XCTAssertNotNil(store.cache[place.id])
        XCTAssertNil(store.errors[place.id])
        XCTAssertTrue(store.cacheWriteFailures.contains(place.id))
        XCTAssertTrue(store.status(for: place, now: now, offline: false).contains("could not save"))
        try FileManager.default.removeItem(at: directory)
        store.storeForecast(forecast, for: place, manuallyRefreshed: true)
        XCTAssertTrue(store.cacheWriteFailures.isEmpty)
        XCTAssertEqual(store.status(for: place, now: now, offline: false), "Recently updated forecast")
        XCTAssertEqual(store.status(for: place, now: now.addingTimeInterval(1800), offline: false), "Cached forecast · refresh for current weather")
        XCTAssertEqual(store.status(for: place, now: now, offline: true), "Offline · cached forecast")
        let reopened = TripWeatherStore(directory: directory)
        XCTAssertEqual(reopened.cache[place.id]?.fetchedAt, now)
    }
    func testBothTemperatureUnitsAndBelowFreezing() {
        let item = CachedWeather(fetchedAt: Date(), observedAt: Date(), celsius: 0, high: nil, low: nil, condition: "Clear", symbol: "sun.max")
        XCTAssertEqual(item.temperatures(0), "32°F / 0°C")
        XCTAssertEqual(item.temperatures(-10), "14°F / -10°C")
        XCTAssertEqual(item.temperatures(25), "77°F / 25°C")
    }
    func testCachePreservesOriginalObservationAndFetchTimes() throws {
        let fetched = Date(timeIntervalSince1970: 10000)
        let observed = Date(timeIntervalSince1970: 9000)
        let item = CachedWeather(fetchedAt: fetched, observedAt: observed, celsius: 25, high: 28, low: 19, condition: "Sunny", symbol: "sun.max.fill")
        let restored = try JSONDecoder().decode(CachedWeather.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(restored.fetchedAt, fetched)
        XCTAssertEqual(restored.observedAt, observed)
        XCTAssertEqual(restored.high, 28)
    }
}

extension WeatherCacheTests {
    func testPreviousCacheFormatStillLoads() throws {
        let item = CachedWeather(fetchedAt: Date(), observedAt: Date(), celsius: 20, high: 25, low: 15, condition: "Clear", symbol: "sun.max")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        json.removeValue(forKey: "hourly"); json.removeValue(forKey: "daily"); json.removeValue(forKey: "timeZoneIdentifier")
        let restored = try JSONDecoder().decode(CachedWeather.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.celsius, 20)
        XCTAssertNil(restored.hourly)
        XCTAssertNil(restored.daily)
    }
    func testForecastsRoundTripAndExpiredHoursAreExcluded() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let hours = (-3..<30).map { offset in CachedWeatherHour(date: now.addingTimeInterval(Double(offset) * 3600), celsius: Double(offset), symbol: "sun.max", condition: "Clear", precipitationChance: 0.2) }
        let day = CachedWeatherDay(date: now, high: 25, low: 15, symbol: "sun.max", condition: "Clear", precipitationChance: 0.4)
        let item = CachedWeather(fetchedAt: now, observedAt: now, celsius: 20, high: 25, low: 15, condition: "Clear", symbol: "sun.max", hourly: Array(hours.reversed()), daily: [day], timeZoneIdentifier: "Asia/Tokyo")
        let restored = try JSONDecoder().decode(CachedWeather.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(restored.upcomingHours(now: now).count, 24)
        XCTAssertEqual(restored.upcomingHours(now: now).first?.date, now.addingTimeInterval(-3600))
        XCTAssertEqual(restored.daily?.first?.precipitationChance, 0.4)
        XCTAssertEqual(restored.timeZoneIdentifier, "Asia/Tokyo")
    }
    func testDailyFilteringUsesDestinationTimeZone() {
        let now = ISO8601DateFormatter().date(from: "2026-10-03T16:30:00Z")!
        let today = ISO8601DateFormatter().date(from: "2026-10-03T15:00:00Z")!
        let yesterday = today.addingTimeInterval(-86400)
        let days = (0..<9).map { offset in CachedWeatherDay(date: today.addingTimeInterval(Double(offset) * 86400), high: 25, low: 15, symbol: "sun.max", condition: "Clear", precipitationChance: 0) }
        let old = CachedWeatherDay(date: yesterday, high: 25, low: 15, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let item = CachedWeather(fetchedAt: now, observedAt: now, celsius: 20, high: 25, low: 15, condition: "Clear", symbol: "sun.max", daily: [old] + days, timeZoneIdentifier: "Asia/Tokyo")
        XCTAssertEqual(item.upcomingDays(now: now).first?.date, today)
        XCTAssertEqual(item.upcomingDays(now: now).count, 7)
    }
}
