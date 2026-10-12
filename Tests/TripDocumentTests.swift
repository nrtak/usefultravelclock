import XCTest
import CryptoKit
import UIKit
@testable import UsefulTravelClock

final class TripDocumentTests: XCTestCase {
    private func pdf(_ text: String) -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400)).pdfData { context in
            context.beginPage()
            (text as NSString).draw(at: CGPoint(x: 20, y: 30), withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
        }
    }
    @MainActor
    func testDocumentsPreserveOriginalBytesAndSurviveRelaunchEncrypted() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = SymmetricKey(size: .bits256)
        let store = TripStore(directory: folder)
        try store.unlockForDocumentTests(key: key)
        let bytes = pdf("Booking ABC123 · boarding pass")
        let payload = try TripDocumentPayload.validate(bytes, filename: "ticket.pdf")
        let record = TravelRecord(kind: "Flight", name: "Example Air")
        store.save(record)
        let doc = try store.importDocument(payload, name: "Outbound", kind: .boardingPass, traveler: "Alex", note: "Terminal 2", recordID: record.id)
        XCTAssertTrue(store.documentAvailable(doc))
        XCTAssertEqual(try Data(contentsOf: store.previewURL(doc)), bytes)
        let vault = TripDocumentVault(directory: folder.appendingPathComponent("Documents"), key: key)
        XCTAssertNotEqual(try Data(contentsOf: vault.file(doc.storageID)), bytes)
        let manifest = try Data(contentsOf: folder.appendingPathComponent("Documents/documents.sealed"))
        XCTAssertNil(manifest.range(of: Data("Alex".utf8)))
        XCTAssertTrue(doc.matches("Example Air", record: record))
        XCTAssertTrue(doc.matches("terminal", record: record))
        XCTAssertFalse(doc.matches("missing", record: record))
        store.lock()
        XCTAssertTrue(store.documents.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("DocumentPreviews").path))
        XCTAssertThrowsError(try store.previewURL(doc))
        let reloaded = TripStore(directory: folder)
        try reloaded.unlockForDocumentTests(key: key)
        XCTAssertEqual(reloaded.documents, [doc])
        XCTAssertEqual(try Data(contentsOf: reloaded.previewURL(doc)), bytes)
        XCTAssertEqual(try payload.recognizedText().contains("ABC123"), true)
    }
    @MainActor
    func testReplaceRetainsIdentityAndLabelsAndDeleteRemovesStorage() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = SymmetricKey(size: .bits256)
        let store = TripStore(directory: folder); try store.unlockForDocumentTests(key: key)
        let first = try TripDocumentPayload.validate(pdf("Old ticket"), filename: "old.pdf")
        let second = try TripDocumentPayload.validate(pdf("Changed ticket"), filename: "new.pdf")
        let old = try store.importDocument(first, name: "Flight", kind: .boardingPass, traveler: "Sam", note: "Window", recordID: nil)
        let updated = try store.importDocument(second, name: old.name, kind: old.kind, traveler: old.traveler, note: old.note, recordID: old.recordID, replacing: old.id)
        XCTAssertEqual(updated.id, old.id)
        XCTAssertEqual(store.documents.count, 1)
        XCTAssertEqual(updated.traveler, "Sam")
        XCTAssertNotEqual(updated.storageID, old.storageID)
        let vault = TripDocumentVault(directory: folder.appendingPathComponent("Documents"), key: key)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.file(old.storageID).path))
        XCTAssertEqual(try vault.data(updated), second.data)
        try store.removeDocuments([updated.id])
        XCTAssertTrue(try vault.load().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vault.file(updated.storageID).path))
    }
    @MainActor
    func testFailedReplacementKeepsExistingFileAndMetadata() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = SymmetricKey(size: .bits256)
        let store = TripStore(directory: folder); try store.unlockForDocumentTests(key: key)
        let payload = try TripDocumentPayload.validate(pdf("Original ticket"), filename: "ticket.pdf")
        let old = try store.importDocument(payload, name: "Flight", kind: .boardingPass, traveler: "", note: "", recordID: nil)
        let manifest = folder.appendingPathComponent("Documents/documents.sealed")
        try FileManager.default.removeItem(at: manifest)
        try FileManager.default.createDirectory(at: manifest, withIntermediateDirectories: false)
        try Data([1]).write(to: manifest.appendingPathComponent("block"))
        XCTAssertThrowsError(try store.importDocument(payload, name: "Changed", kind: .other, traveler: "", note: "", recordID: nil, replacing: old.id))
        XCTAssertEqual(store.documents, [old])
        let vault = TripDocumentVault(directory: folder.appendingPathComponent("Documents"), key: key)
        XCTAssertEqual(try vault.data(old), payload.data)
        let files = try FileManager.default.contentsOfDirectory(at: vault.directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent != "documents.sealed" }
        XCTAssertEqual(files.count, 1)
    }
    @MainActor
    func testDeletingTripKeepsDocumentsForReassignment() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TripStore(directory: folder); try store.unlockForDocumentTests(key: SymmetricKey(size: .bits256))
        let record = TravelRecord(name: "Hotel")
        store.save(record)
        let payload = try TripDocumentPayload.validate(pdf("Reservation"), filename: "reservation.pdf")
        let doc = try store.importDocument(payload, name: "Hotel", kind: .confirmation, traveler: "", note: "", recordID: record.id)
        try store.removeRecord(record.id)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(store.documentAvailable(doc))
        var edited = doc; edited.recordID = nil; edited.name = "Saved reservation"
        try store.updateDocument(edited)
        XCTAssertNil(store.documents.first?.recordID)
    }
    func testImportValidationAndBookingLinks() throws {
        XCTAssertThrowsError(try TripDocumentPayload.validate(Data("not a file".utf8), filename: "fake.pdf"))
        XCTAssertThrowsError(try TripDocumentPayload.validate(Data(repeating: 0, count: TripDocumentPayload.maximumBytes + 1), filename: "large.pdf"))
        XCTAssertEqual(try TripDocumentPayload.validate(pdf("Travel"), filename: "../folder/ticket.exe").filename, "ticket.pdf")
        XCTAssertNil(TripBookingLink.url("javascript:alert(1)"))
        XCTAssertNil(TripBookingLink.url("https://user:password@example.com"))
        XCTAssertNil(TripBookingLink.url("http://example.com"))
        XCTAssertNotNil(TripBookingLink.url("https://www.jal.co.jp/en-us/my-booking.html"))
        XCTAssertTrue(TripBookingLink.airlines.allSatisfy { TripBookingLink.url($0.url) != nil })
    }
    func testOldTravelRecordRemainsReadable() throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TravelRecord(name: "Existing trip"))) as? [String: Any])
        for key in ["bookingReference", "bookingWebsite", "traveler"] { json.removeValue(forKey: key) }
        let record = try JSONDecoder().decode(TravelRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(record.name, "Existing trip")
        XCTAssertNil(record.bookingReference)
        XCTAssertNil(record.bookingWebsite)
    }
}
