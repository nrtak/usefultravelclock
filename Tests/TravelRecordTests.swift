import XCTest
import CryptoKit
@testable import UsefulTravelClock

final class TravelRecordTests: XCTestCase {
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
