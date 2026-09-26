// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

import XCTest
@testable import UsefulTravelClock

final class ConverterTests: XCTestCase {
    func testConversionAcrossDateLineAndFractionalOffsets() throws {
        let cases = [
            ("2026-01-01", "00:15", "Pacific/Kiritimati", "2025-12-31T10:15:00Z"),
            ("2026-01-01", "23:45", "Pacific/Pago_Pago", "2026-01-02T10:45:00Z"),
            ("2026-07-01", "12:00", "Asia/Kathmandu", "2026-07-01T06:15:00Z"),
            ("2026-01-01", "12:00", "America/Los_Angeles", "2026-01-01T20:00:00Z"),
            ("2026-07-01", "12:00", "America/Los_Angeles", "2026-07-01T19:00:00Z"),
            ("2028-02-29", "00:00", "UTC", "2028-02-29T00:00:00Z")
        ]
        for (day, time, zone, expected) in cases {
            let date = try XCTUnwrap(TimeEngine.fromZonedInput(day: day, time: time, timeZoneID: zone))
            XCTAssertEqual(date, try instant(expected), "\(zone): \(day) \(time)")
            let roundTrip = TimeEngine.toZonedInput(date, timeZoneID: zone)
            XCTAssertEqual(roundTrip.day, day)
            XCTAssertEqual(roundTrip.time, time)
        }
    }

    func testSkippedLocalTimesAreRejected() {
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-03-08", time: "02:30", timeZoneID: "America/New_York"))
        // Lord Howe advances by half an hour, not one hour.
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-10-04", time: "02:15", timeZoneID: "Australia/Lord_Howe"))
        // Samoa skipped an entire calendar date when it moved across the date line.
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2011-12-30", time: "12:00", timeZoneID: "Pacific/Apia"))
    }

    func testBothOccurrencesOfRepeatedTimeCanBeSelected() throws {
        let first = try XCTUnwrap(TimeEngine.fromZonedInput(
            day: "2026-11-01", time: "01:30", timeZoneID: "America/New_York"))
        let last = try XCTUnwrap(TimeEngine.fromZonedInput(
            day: "2026-11-01", time: "01:30", timeZoneID: "America/New_York", repeatedTimePolicy: .last))
        XCTAssertEqual(first, try instant("2026-11-01T05:30:00Z"))
        XCTAssertEqual(last, try instant("2026-11-01T06:30:00Z"))
    }

    func testHalfHourRepeatedTime() throws {
        let first = try XCTUnwrap(TimeEngine.fromZonedInput(
            day: "2026-04-05", time: "01:45", timeZoneID: "Australia/Lord_Howe"))
        let last = try XCTUnwrap(TimeEngine.fromZonedInput(
            day: "2026-04-05", time: "01:45", timeZoneID: "Australia/Lord_Howe", repeatedTimePolicy: .last))
        XCTAssertEqual(first, try instant("2026-04-04T14:45:00Z"))
        XCTAssertEqual(last, try instant("2026-04-04T15:15:00Z"))
    }

    func testOrdinaryTimeDoesNotDependOnOccurrencePolicy() throws {
        let first = try XCTUnwrap(TimeEngine.fromZonedInput(day: "2026-07-01", time: "12:00", timeZoneID: "Asia/Tokyo"))
        let last = TimeEngine.fromZonedInput(day: "2026-07-01", time: "12:00", timeZoneID: "Asia/Tokyo", repeatedTimePolicy: .last)
        XCTAssertEqual(first, last)
    }

    func testInvalidInputsAreNotNormalized() {
        for day in ["2026-02-29", "2026-04-31", "2026-00-01", "2026-13-01", "2026-01-00", "0000-01-01", "2026-1-1", "invalid"] {
            XCTAssertNil(TimeEngine.fromZonedInput(day: day, time: "12:00", timeZoneID: "UTC"), day)
        }
        for time in ["24:00", "12:60", "-1:00", "12:00:30", "1:00", "12:xx", ""] {
            XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-01-01", time: time, timeZoneID: "UTC"), time)
        }
        XCTAssertNil(TimeEngine.fromZonedInput(day: "2026-01-01", time: "12:00", timeZoneID: "Invalid/Zone"))
    }

    private func instant(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
