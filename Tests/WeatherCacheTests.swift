import XCTest
@testable import UsefulTravelClock

final class WeatherCacheTests: XCTestCase {
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
