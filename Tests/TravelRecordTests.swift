import XCTest
import CryptoKit
@testable import UsefulTravelClock

final class TravelRecordTests: XCTestCase {
    func testTripOrderAndStatusAdvanceAtBookingBoundaries() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let current = TravelRecord(kind: "Flight", name: "Current", start: start, end: start.addingTimeInterval(3600))
        let upcoming = TravelRecord(kind: "Flight", name: "Next", start: start.addingTimeInterval(1800), end: start.addingTimeInterval(7200))
        let records = [upcoming, current]
        XCTAssertEqual(current.timingLabel(at: start.addingTimeInterval(-1)), "Upcoming")
        XCTAssertEqual(current.timingLabel(at: start), "Happening now")
        XCTAssertEqual(current.timingLabel(at: current.end), "Completed")
        XCTAssertEqual(TripSummary.orderedRecords(in: records, at: start).map(\.name), ["Current", "Next"])
        XCTAssertEqual(TripSummary.orderedRecords(in: records, at: current.end).map(\.name), ["Next", "Current"])
    }

    func testUnifiedTripListKeepsCurrentAndUpcomingBookingsAheadOfHistory() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = TravelRecord(start: now.addingTimeInterval(-400), end: now.addingTimeInterval(-300))
        let recent = TravelRecord(start: now.addingTimeInterval(-200), end: now)
        let active = TravelRecord(start: now.addingTimeInterval(-50), end: now.addingTimeInterval(50))
        let soon = TravelRecord(start: now.addingTimeInterval(100), end: now.addingTimeInterval(200))
        let later = TravelRecord(start: now.addingTimeInterval(300), end: now.addingTimeInterval(400))
        XCTAssertEqual(TripSummary.orderedRecords(in: [old, later, recent, soon, active], at: now).map(\.id), [active.id, soon.id, later.id, recent.id, old.id])
        XCTAssertTrue(TripSummary.orderedRecords(in: [], at: now).isEmpty)
    }

    func testSummaryPrefersOngoingJourneyAndSkipsCompletedRecords() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let past = TravelRecord(start: now.addingTimeInterval(-200), end: now.addingTimeInterval(-100))
        let active = TravelRecord(start: now.addingTimeInterval(-50), end: now.addingTimeInterval(50))
        let future = TravelRecord(start: now.addingTimeInterval(100), end: now.addingTimeInterval(200))
        XCTAssertEqual(TripSummary.record(in: [future, past, active], at: now)?.id, active.id)
        XCTAssertEqual(TripSummary.record(in: [past, future], at: now)?.id, future.id)
        XCTAssertNil(TripSummary.record(in: [past], at: now))
        XCTAssertNil(TripSummary.record(in: [], at: now))
        XCTAssertEqual(TripSummary.record(in: [active, future], at: active.end)?.id, future.id)
    }

    @MainActor
    func testLockedSaveFailsWithoutCreatingTravelFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TripStore(directory: folder)
        XCTAssertFalse(store.save(TravelRecord(note: "Keep my draft")))
        XCTAssertNotNil(store.error)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("travel.sealed").path))
    }

    @MainActor
    func testSaveFailurePreservesLastPersistedRecordAndSuccessfulRetryClearsError() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TripStore(directory: folder)
        let key = SymmetricKey(size: .bits256)
        try store.unlockForDocumentTests(key: key)
        var record = TravelRecord(note: "Original note")
        XCTAssertTrue(store.save(record))
        let file = folder.appendingPathComponent("travel.sealed")
        let original = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        record.note = "Long updated note\n" + String(repeating: "Travel details ", count: 500)
        XCTAssertFalse(store.save(record))
        XCTAssertEqual(store.records.first?.note, "Original note")
        XCTAssertNotNil(store.error)
        try FileManager.default.removeItem(at: file)
        try original.write(to: file)
        XCTAssertTrue(store.save(record))
        XCTAssertNil(store.error)
        let clear = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: file)), using: key)
        let loaded = try JSONDecoder().decode([TravelRecord].self, from: clear)
        XCTAssertEqual(loaded.first?.note, record.note)
        store.lock()
        XCTAssertFalse(store.save(record))
    }

    func testTravelRecordEncryptionRoundTripAndWrongKey() throws {
        let record = TravelRecord(kind: "Hotel", name: "Private Hotel", reference: "CONF-123", from: "123 Private Street")
        let key = SymmetricKey(size: .bits256)
        let clear = try JSONEncoder().encode([record])
        let sealed = try AES.GCM.seal(clear, using: key)
        let combined = try XCTUnwrap(sealed.combined)
        XCTAssertNil(combined.range(of: Data("123 Private Street".utf8)))
        let recovered = try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: key)
        let records = try JSONDecoder().decode([TravelRecord].self, from: recovered)
        XCTAssertEqual(records.first?.id, record.id)
        XCTAssertEqual(records.first?.from, record.from)
        XCTAssertThrowsError(try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: SymmetricKey(size: .bits256)))
    }
    func testTranslationKeepsTextNotesAndImageTogether() throws {
        let record = TranslationRecord(text: "Green tea", note: "Menu at the station", image: Data([1,2,3]))
        let copy = try JSONDecoder().decode(TranslationRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(copy.id, record.id)
        XCTAssertEqual(copy.text, record.text)
        XCTAssertEqual(copy.note, record.note)
        XCTAssertEqual(copy.image, record.image)
    }
    func testLegacyRecordLoadsWithoutTimeZones() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TravelRecord())) as? [String: Any])
        for key in ["departureTimeZone", "arrivalTimeZone", "departureCity", "arrivalCity"] { object.removeValue(forKey: key) }
        let record = try JSONDecoder().decode(TravelRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(record.departureTimeZone)
        XCTAssertEqual(record.zone(start: true), TimeZone.current)
    }
    func testIndependentLocalZonesAndHotelFallback() throws {
        var record = TravelRecord(kind: "Flight")
        record.departureTimeZone = "America/Los_Angeles"
        record.arrivalTimeZone = "Asia/Tokyo"
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-05T00:00:00Z"))
        XCTAssertEqual(record.zone(start: true).secondsFromGMT(for: date), -7 * 3600)
        XCTAssertEqual(record.zone(start: false).secondsFromGMT(for: date), 9 * 3600)
        let copy = try JSONDecoder().decode(TravelRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(copy.arrivalTimeZone, "Asia/Tokyo")
        record.kind = "Hotel"; record.arrivalTimeZone = nil
        XCTAssertEqual(record.zone(start: false), record.zone(start: true))
    }
}
