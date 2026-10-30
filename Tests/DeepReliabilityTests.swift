import XCTest
import CryptoKit
import UIKit
@testable import UsefulTravelClock

final class DeepReliabilityTests: XCTestCase {
    @MainActor
    func testDraftCleanupFailureKeepsSaveIncompleteAndRetryPreservesNewestTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TripStore(directory: directory)
        try store.unlockForDocumentTests(key: SymmetricKey(size: .bits256))
        var record = TravelRecord(name: "Flight", note: "Older draft")
        XCTAssertTrue(store.saveDraft(record))
        let draftFile = directory.appendingPathComponent("drafts.sealed")
        try FileManager.default.removeItem(at: draftFile)
        try FileManager.default.createDirectory(at: draftFile, withIntermediateDirectories: true)
        try Data([1]).write(to: draftFile.appendingPathComponent("block-write"))
        record.note = "Latest saved details"
        XCTAssertFalse(store.save(record), "The editor must remain open until its old draft can be cleared")
        XCTAssertEqual(store.records.first?.note, record.note)
        XCTAssertEqual(store.drafts.first?.note, "Older draft")
        XCTAssertNotNil(store.error)
        try FileManager.default.removeItem(at: draftFile)
        XCTAssertTrue(store.save(record))
        XCTAssertTrue(store.drafts.isEmpty)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.note, "Latest saved details")
    }

    @MainActor
    func testRepeatedCurrencySaveCannotDuplicateOrReplaceCommittedPhoto() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = SavedConversions(directory: directory)
        var draft = SavedConversion(id: UUID(), savedAt: Date(), source: "USD", target: "EUR", amount: 10, multiplier: 0.9, convertedAmount: 9, rateDates: [], ratesCheckedAt: nil, note: "Original", photoFilename: nil)
        let photo = Data([1, 2, 3])
        try library.save(draft, photo: photo)
        let first = try XCTUnwrap(library.items.first)
        draft.note = "Repeated callback"
        try library.save(draft, photo: Data([9, 9, 9]))
        XCTAssertEqual(library.items, [first])
        XCTAssertEqual(library.lastSavedID, first.id)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(library.photoURL(for: first))), photo)
        XCTAssertEqual(SavedConversions(directory: directory).items, [first])
    }

    func testCrossRateReadinessChecksBothLegs() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-30T12:00:00Z"))
        let recent = Rate(date: "2026-10-29", base: "USD", quote: "EUR", rate: 0.9)
        let incomplete = RateSnapshot(fetchedAt: now, rows: [recent])
        XCTAssertTrue(incomplete.needsRefresh(from: "EUR", to: "JPY", now: now))
        let future = Rate(date: "2026-11-02", base: "USD", quote: "JPY", rate: 150)
        let unexpected = RateSnapshot(fetchedAt: now, rows: [recent, future])
        XCTAssertTrue(unexpected.needsRefresh(from: "EUR", to: "JPY", now: now))
        XCTAssertTrue(unexpected.needsRefresh(from: "JPY", to: "EUR", now: now))
        let valid = RateSnapshot(fetchedAt: now, rows: [recent, Rate(date: "2026-10-29", base: "USD", quote: "JPY", rate: 150)])
        XCTAssertFalse(valid.needsRefresh(from: "EUR", to: "JPY", now: now))
        XCTAssertFalse(incomplete.needsRefresh(from: "USD", to: "USD", now: now))
    }

    @MainActor
    func testInterruptedImportStaysQueuedUntilItsPayloadIsPreserved() {
        let inbox = TripDocumentInbox()
        defer { inbox.clear() }
        let first = URL(fileURLWithPath: "/tmp/first.pdf")
        let second = URL(fileURLWithPath: "/tmp/second.pdf")
        inbox.receive(first); inbox.receive(second)
        inbox.finishCurrent(ifMatching: first, preserved: false, interrupted: true)
        XCTAssertEqual(inbox.url, first)
        inbox.markPreserved(first)
        inbox.finishCurrent(ifMatching: first, preserved: false, interrupted: true)
        XCTAssertEqual(inbox.url, second)
        XCTAssertFalse(inbox.currentPreserved)
        // A delayed dismissal callback for the previous file must not drop the next one.
        inbox.finishCurrent(ifMatching: first)
        XCTAssertEqual(inbox.url, second)
        inbox.markPreserved(first)
        XCTAssertFalse(inbox.currentPreserved)
        inbox.finishCurrent(ifMatching: second, preserved: false, interrupted: false)
        XCTAssertNil(inbox.url, "An intentional cancel can advance the queue")
    }

    @MainActor
    func testDocumentRecognitionUsesBoundedPixelsAndKeepsOriginalFile() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let original = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 1000), format: format).image { context in
            UIColor.white.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: 4000, height: 1000))
        }
        let bytes = try XCTUnwrap(original.jpegData(compressionQuality: 0.85))
        let payload = try TripDocumentPayload.validate(bytes, filename: "Wide document.jpg")
        let image = try payload.recognitionImage()
        XCTAssertLessThanOrEqual(max(image.width, image.height), 2000)
        XCTAssertEqual(image.width, image.height * 4)
        XCTAssertEqual(payload.data, bytes)
    }

    func testUnfinishedImportCannotBeReplacedByAnotherFileOrReplacement() {
        let original = UUID(), another = UUID()
        let draft = TripImportDraft(replacingID: original, note: "Unfinished private labels")
        XCTAssertTrue(draft.canResume(replacing: nil, hasIncomingFile: false))
        XCTAssertTrue(draft.canResume(replacing: original, hasIncomingFile: false))
        XCTAssertFalse(draft.canResume(replacing: another, hasIncomingFile: false))
        XCTAssertFalse(draft.canResume(replacing: nil, hasIncomingFile: true))
        XCTAssertFalse(draft.canResume(replacing: original, hasIncomingFile: true))
        XCTAssertFalse(TripImportDraft().canResume(replacing: original, hasIncomingFile: false))
    }

    func testInvalidWeatherValuesCannotTrapWhileFormatting() {
        let forecast = CachedWeather(fetchedAt: Date(), observedAt: Date(), celsius: 20, high: nil, low: nil, condition: "Clear", symbol: "sun.max")
        for value in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
            XCTAssertEqual(forecast.temperatures(value), "Unavailable")
        }
        XCTAssertEqual(forecast.temperatures(20), "68°F / 20°C")
        XCTAssertNil(CachedWeather.precipitationPercent(.nan))
        XCTAssertNil(CachedWeather.precipitationPercent(.infinity))
        XCTAssertEqual(CachedWeather.precipitationPercent(0.5), 50)
        XCTAssertEqual(CachedWeather.precipitationPercent(2), 100)
        XCTAssertEqual(CachedWeather.precipitationPercent(-0.5), 0)
    }
}
