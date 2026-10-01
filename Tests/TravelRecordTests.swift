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
}
