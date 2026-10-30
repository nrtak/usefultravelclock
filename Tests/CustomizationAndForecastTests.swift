import XCTest
@testable import UsefulTravelClock

final class CustomizationAndForecastTests: XCTestCase {
    func testTabsKeepStableIdentitiesAndAlwaysOfferAVisibleTab() {
        XCTAssertEqual(DashboardTab.decode("2,0,2,99,1"), [.tools, .home, .trip])
        XCTAssertEqual(DashboardTab.decode("obsolete"), DashboardTab.allCases)
        let moved = DashboardTab.moving(.home, to: .tools, in: DashboardTab.defaults)
        XCTAssertEqual(DashboardTab.decode(moved), [.trip, .tools, .home])
        let hidden = DashboardTab.removing(.trip, from: moved)
        XCTAssertEqual(DashboardTab.decode(hidden), [.tools, .home])
        XCTAssertEqual(DashboardTab.decode(DashboardTab.showing(.trip, in: hidden)), [.tools, .home, .trip])
        XCTAssertEqual(DashboardTab.removing(.tools, from: "2"), "2")
        XCTAssertEqual(DashboardTab.showing(.tools, in: "2"), "2")
    }

    func testDraggingHomeCardsPreservesHiddenChoicesAndAllowsAnEmptyHome() {
        let saved = "clocks,currency,trip,weather,documents"
        let moved = HomeSection.moving(.clocks, to: .trip, in: saved)
        XCTAssertEqual(HomeSection.decode(moved), [.currency, .trip, .clocks, .weather, .documents])
        XCTAssertEqual(HomeSection.moving(.readiness, to: .trip, in: saved), saved)
        XCTAssertEqual(HomeSection.encode(HomeSection.decode("currency").filter { $0 != .currency }), "")
        XCTAssertTrue(HomeSection.decode("").isEmpty)
    }

    func testTomorrowUsesForecastCityCalendarAcrossDaylightSavingChange() throws {
        let formatter = ISO8601DateFormatter()
        let now = try XCTUnwrap(formatter.date(from: "2026-11-01T04:30:00Z"))
        let stamps = ["2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z", "2026-11-03T05:00:00Z"]
        let days = try stamps.map { value in
            CachedWeatherDay(date: try XCTUnwrap(formatter.date(from: value)), high: 20, low: 10, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        }
        let forecast = CachedWeather(fetchedAt: now, observedAt: now, celsius: 20, high: 20, low: 10, condition: "Clear", symbol: "sun.max", daily: days, timeZoneIdentifier: "America/New_York")
        XCTAssertEqual(forecast.forecastDays(for: .tomorrow, now: now).map(\.date), [days[1].date])
        XCTAssertTrue(forecast.forecastDays(for: .hourly, now: now).isEmpty)
    }

    func testFiveAndSevenDayOptionsHaveDifferentLengthsAndTomorrowIsNotUTC() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-30T16:30:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let start = calendar.startOfDay(for: now)
        let days = try (0..<8).map { offset in
            CachedWeatherDay(date: try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start)), high: 20, low: 10, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        }
        let hours = (0..<24).map { offset in
            CachedWeatherHour(date: now.addingTimeInterval(Double(offset) * 3600), celsius: 20, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        }
        let forecast = CachedWeather(fetchedAt: now, observedAt: now, celsius: 20, high: 20, low: 10, condition: "Clear", symbol: "sun.max", hourly: hours, daily: days, timeZoneIdentifier: "Asia/Tokyo")
        XCTAssertEqual(forecast.forecastDays(for: .fiveDays, now: now).count, 5)
        XCTAssertEqual(forecast.forecastDays(for: .week, now: now).count, 7)
        XCTAssertEqual(forecast.forecastDays(for: .tomorrow, now: now).map(\.date), [days[1].date])
        XCTAssertEqual(forecast.upcomingHours(now: now).count, 24)
    }

    func testDuplicateCachedRowsDoNotRepeatIDsOrHideTomorrowsForecast() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-30T12:00:00Z"))
        let today = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-30T00:00:00Z"))
        let next = today.addingTimeInterval(86400)
        let first = CachedWeatherDay(date: today, high: 20, low: 10, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let tomorrow = CachedWeatherDay(date: next, high: 21, low: 11, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let hour = CachedWeatherHour(date: now, celsius: 20, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let nextHour = CachedWeatherHour(date: now.addingTimeInterval(3600), celsius: 21, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let invalidDate = Date(timeIntervalSince1970: .greatestFiniteMagnitude)
        let invalidDay = CachedWeatherDay(date: invalidDate, high: 20, low: 10, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let invalidHour = CachedWeatherHour(date: invalidDate, celsius: 20, symbol: "sun.max", condition: "Clear", precipitationChance: 0)
        let forecast = CachedWeather(fetchedAt: now, observedAt: now, celsius: 20, high: 20, low: 10, condition: "Clear", symbol: "sun.max", hourly: [invalidHour, hour, hour, nextHour], daily: [invalidDay] + Array(repeating: first, count: 8) + [tomorrow], timeZoneIdentifier: "UTC")
        XCTAssertEqual(forecast.upcomingHours(now: now).map(\.id), [hour.id, nextHour.id])
        XCTAssertEqual(forecast.upcomingDays(now: now).map(\.id), [first.id, tomorrow.id])
        XCTAssertEqual(forecast.forecastDays(for: .tomorrow, now: now).map(\.id), [tomorrow.id])
    }
}
