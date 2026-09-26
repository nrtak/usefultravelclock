// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

import XCTest
@testable import UsefulTravelClock

final class ClockTests: XCTestCase {
    @MainActor
    func testPreferencesSurviveRelaunchAndAreReadableByWidgets() throws {
        let suite = "clock-tests-\(UUID().uuidString)"
        let storage = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { storage.removePersistentDomain(forName: suite) }
        let original = UsefulTravelClockStore(defaults: storage)
        let city = try XCTUnwrap(cities.first { $0.timeZoneID == "Asia/Tokyo" })
        original.cityIDs = [city.id]
        original.theme = .dark
        original.homeMode = .manual
        original.homeCityID = city.id

        let reopened = UsefulTravelClockStore(defaults: storage)
        XCTAssertEqual(reopened.cityIDs, [city.id])
        XCTAssertEqual(reopened.theme, .dark)
        XCTAssertEqual(reopened.homeMode, .manual)
        XCTAssertEqual(reopened.homeTimeZoneID, "Asia/Tokyo")
        XCTAssertEqual(storage.string(forKey: "usefultravelclock-home-city"), city.id)
        XCTAssertEqual(storage.string(forKey: "usefultravelclock-home-mode"), "manual")
        let snapshot = WidgetSnapshot.current(from: reopened)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.homeTimeZoneID, "Asia/Tokyo")
    }

    @MainActor
    func testEmptyCitySelectionSurvivesRelaunch() throws {
        let suite = "clock-tests-\(UUID().uuidString)"
        let storage = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { storage.removePersistentDomain(forName: suite) }
        let store = UsefulTravelClockStore(defaults: storage)
        store.cityIDs = []
        XCTAssertTrue(UsefulTravelClockStore(defaults: storage).cityIDs.isEmpty)
    }

    func testSeasonalAndFractionalOffsets() throws {
        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z"))
        let winter = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z"))
        XCTAssertEqual(TimeEngine.timeDifferenceMinutes(summer, timeZoneID: "Asia/Tokyo", homeTimeZoneID: "America/Los_Angeles"), 960)
        XCTAssertEqual(TimeEngine.timeDifferenceMinutes(winter, timeZoneID: "Asia/Tokyo", homeTimeZoneID: "America/Los_Angeles"), 1020)
        XCTAssertEqual(TimeEngine.timeDifferenceMinutes(summer, timeZoneID: "Asia/Kathmandu", homeTimeZoneID: "UTC"), 345)
    }

    func testAirportSearch() {
        XCTAssertTrue(CitySearch.search("LAX", in: cities).contains { $0.timeZoneID == "America/Los_Angeles" })
    }
}
