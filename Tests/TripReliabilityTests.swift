import XCTest
import CryptoKit
import UserNotifications
@testable import UsefulTravelClock

@MainActor final class MemoryTripNotifications: TripNotificationClient {
    var values: [String: UNNotificationRequest] = [:]
    var allowed = true
    var fail = false
    func requestAccess() async throws -> Bool { allowed }
    func pending() async -> [UNNotificationRequest] { Array(values.values) }
    func add(_ request: UNNotificationRequest) async throws {
        if fail { throw CocoaError(.fileWriteUnknown) }
        values[request.identifier] = request
    }
    func remove(_ identifiers: [String]) { for id in identifiers { values[id] = nil } }
}

@MainActor final class TripReliabilityTests: XCTestCase {
    private func folder() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func store(_ folder: URL) -> TripStore { TripStore(directory: folder, reminders: TripReminderStore(client: MemoryTripNotifications())) }

    func testDraftAndLegacyTripsSurviveUpgradeAndLockWithoutPlaintext() throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let key = SymmetricKey(size: .bits256)
        let original = store(directory); try original.unlockForDocumentTests(key: key)
        var record = TravelRecord(name: "Private hotel", note: "Original note")
        // Model the record schema from before reminder settings were introduced.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        object.removeValue(forKey: "reminderMinutes")
        let old = try JSONDecoder().decode(TravelRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.reminderMinutes)
        XCTAssertTrue(original.save(old))
        record.note = "Unfinished private note\n" + String(repeating: "More travel detail ", count: 1000)
        XCTAssertTrue(original.saveDraft(record))
        let encrypted = try Data(contentsOf: directory.appendingPathComponent("drafts.sealed"))
        XCTAssertNil(encrypted.range(of: Data("Unfinished private note".utf8)))
        original.lock(); XCTAssertTrue(original.drafts.isEmpty)
        let reopened = store(directory); try reopened.unlockForDocumentTests(key: key)
        XCTAssertEqual(reopened.records.first?.note, "Original note")
        XCTAssertEqual(reopened.drafts.first, record)
        XCTAssertTrue(reopened.save(record))
        XCTAssertTrue(reopened.drafts.isEmpty)
        let final = store(directory); try final.unlockForDocumentTests(key: key)
        XCTAssertEqual(final.records.first, record)
        XCTAssertTrue(final.drafts.isEmpty)
    }

    func testWrongKeyCannotOverwriteExistingTrips() throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let original = store(directory); try original.unlockForDocumentTests(key: SymmetricKey(size: .bits256))
        XCTAssertTrue(original.save(TravelRecord(name: "Existing trip")))
        let file = directory.appendingPathComponent("travel.sealed")
        let bytes = try Data(contentsOf: file)
        let reopened = store(directory)
        XCTAssertThrowsError(try reopened.unlockForDocumentTests(key: SymmetricKey(size: .bits256)))
        XCTAssertFalse(reopened.save(TravelRecord(name: "Replacement")))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    func testBackgroundInvalidatesPendingUnlockAndFreshUnlockStillWorks() async throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        var completions: [CheckedContinuation<Data, Error>] = []
        let material = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let value = TripStore(directory: directory, keyLoader: { _ in try await withCheckedThrowingContinuation { completions.append($0) } }, reminders: TripReminderStore(client: MemoryTripNotifications()))
        let first = Task { await value.unlock() }
        for _ in 0..<1000 { if completions.count >= 1 { break }; await Task.yield() }
        guard completions.count >= 1 else { XCTFail("First unlock did not request its key"); first.cancel(); return }
        XCTAssertTrue(value.loading)
        value.lock()
        let second = Task { await value.unlock() }
        for _ in 0..<1000 { if completions.count >= 2 { break }; await Task.yield() }
        guard completions.count >= 2 else { completions[0].resume(returning: material); await first.value; second.cancel(); XCTFail("Second unlock did not request its key"); return }
        completions[0].resume(returning: material)
        await first.value
        XCTAssertFalse(value.unlocked)
        XCTAssertTrue(value.loading, "A stale unlock must not clear the newer request's loading state")
        completions[1].resume(returning: material)
        await second.value
        XCTAssertTrue(value.unlocked)
        XCTAssertFalse(value.loading)
        value.lock()
        XCTAssertTrue(value.records.isEmpty)
    }

    func testSearchAndInvalidDateValidation() throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let value = store(directory); try value.unlockForDocumentTests(key: SymmetricKey(size: .bits256))
        let record = TravelRecord(kind: "Flight", name: "Air Example", from: "Los Angeles", to: "Tokyo", start: Date(timeIntervalSince1970: 100), end: Date(timeIntervalSince1970: 50), note: "Terminal 2", bookingReference: "ABC123", traveler: "José")
        for query in [" TOKYO ", "jose", "ABC123", "Terminal"] { XCTAssertTrue(record.matches(query)) }
        XCTAssertFalse(record.matches("missing"))
        XCTAssertNotNil(record.dateWarning)
        XCTAssertFalse(value.save(record))
        XCTAssertTrue(value.records.isEmpty)
    }

    func testReadinessDetectsMissingAndDamagedEncryptedDocuments() async throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let key = SymmetricKey(size: .bits256)
        let value = store(directory); try value.unlockForDocumentTests(key: key)
        let bytes = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="))
        let payload = try TripDocumentPayload.validate(bytes, filename: "ticket.png")
        let record = TravelRecord(name: "Current trip", start: Date().addingTimeInterval(-100), end: Date().addingTimeInterval(1000))
        XCTAssertTrue(value.save(record))
        let document = try value.importDocument(payload, name: "Ticket", kind: .boardingPass, traveler: "", note: "", recordID: record.id)
        let readable = await value.readableDocuments()
        XCTAssertTrue(readable.contains(document.id))
        XCTAssertEqual(value.summaryDocument(at: Date())?.id, document.id)
        let file = directory.appendingPathComponent("Documents/" + document.storageID.uuidString + ".sealed")
        try Data([1, 2, 3]).write(to: file)
        let damaged = await value.readableDocuments()
        XCTAssertFalse(damaged.contains(document.id))
        XCTAssertThrowsError(try value.previewURL(document))
        try FileManager.default.removeItem(at: file)
        XCTAssertNil(value.summaryDocument(at: Date()))
        value.lock()
        let locked = await value.readableDocuments()
        XCTAssertTrue(locked.isEmpty)
    }

    func testImportDraftCanResumeOriginalBytesAndPartialSaveWithoutDuplicatingDocument() throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let key = SymmetricKey(size: .bits256)
        let value = store(directory); try value.unlockForDocumentTests(key: key)
        // A known valid one-pixel PNG exercises image validation without a network fixture.
        let bytes = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII="))
        let payload = try TripDocumentPayload.validate(bytes, filename: "ticket.png")
        var draft = TripImportDraft(name: "Private ticket", bookingReference: "SECRET123")
        try value.saveImportDraft(draft, payload: payload)
        let saved = try value.importDocument(payload, name: draft.name, kind: .boardingPass, traveler: "", note: "", recordID: nil, idempotencyID: draft.storageID)
        let retried = try value.importDocument(payload, name: draft.name, kind: .boardingPass, traveler: "", note: "", recordID: nil, idempotencyID: draft.storageID)
        XCTAssertEqual(retried.id, saved.id)
        XCTAssertEqual(value.documents.count, 1)
        draft.savedDocumentID = saved.id
        try value.saveImportDraft(draft)
        value.lock()
        let reopened = store(directory); try reopened.unlockForDocumentTests(key: key)
        XCTAssertEqual(reopened.importDraft, draft)
        XCTAssertEqual(try reopened.importDraftPayload().data, bytes)
        XCTAssertEqual(reopened.documents.count, 1)
        let metadata = try Data(contentsOf: directory.appendingPathComponent("ImportDraft/metadata.sealed"))
        XCTAssertNil(metadata.range(of: Data("SECRET123".utf8)))
        try reopened.discardImportDraft()
        XCTAssertNil(reopened.importDraft)
        XCTAssertEqual(reopened.documents.count, 1)
    }

    func testBookingReferenceUpdateDoesNotEraseUnfinishedTripEdits() throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let value = store(directory); try value.unlockForDocumentTests(key: SymmetricKey(size: .bits256))
        var record = TravelRecord(name: "Flight", note: "Saved note")
        XCTAssertTrue(value.save(record))
        var draft = record; draft.note = "Unfinished edited note"
        XCTAssertTrue(value.saveDraft(draft))
        record.bookingReference = "NEW123"
        XCTAssertTrue(value.save(record, clearDraft: false))
        XCTAssertEqual(value.drafts.first?.note, "Unfinished edited note")
        XCTAssertEqual(value.records.first?.bookingReference, "NEW123")
    }

    func testRemindersUseAbsoluteBookingTimeAndReconcileEditsAndDeletion() async throws {
        let client = MemoryTripNotifications(); let value = TripReminderStore(client: client)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var record = TravelRecord(kind: "Flight", reference: "PRIVATE123", start: now.addingTimeInterval(7200), end: now.addingTimeInterval(14400), departureTimeZone: "Asia/Tokyo", reminderMinutes: 60)
        let fire = try XCTUnwrap(TripReminderStore.fireDate(for: record))
        let request = try XCTUnwrap(TripReminderStore.request(for: record, now: now))
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.timeZone, .gmt)
        XCTAssertEqual(trigger.dateComponents.calendar?.date(from: trigger.dateComponents), fire)
        XCTAssertFalse(request.content.body.contains("PRIVATE123"))
        record.departureTimeZone = "America/Los_Angeles"
        XCTAssertEqual(TripReminderStore.fireDate(for: record), fire)
        await value.synchronize(records: [record], now: now)
        XCTAssertEqual(client.values.count, 1)
        record.reminderMinutes = 30
        await value.synchronize(records: [record], now: now)
        XCTAssertEqual(client.values.count, 1)
        record.reminderMinutes = nil
        await value.synchronize(records: [record], now: now)
        XCTAssertTrue(client.values.isEmpty)
        record.reminderMinutes = 60
        client.fail = true
        await value.synchronize(records: [record], now: now)
        XCTAssertNotNil(value.message)
        client.allowed = false
        let allowed = await value.requestAccess()
        XCTAssertFalse(allowed)
        XCTAssertNotNil(value.message)
        XCTAssertNil(TripReminderStore.request(for: record, now: record.start))
    }

    func testReminderLimitAndDeletionPreserveUnrelatedNotifications() async {
        let client = MemoryTripNotifications(); let value = TripReminderStore(client: client)
        let content = UNMutableNotificationContent(); content.title = "Unrelated"
        client.values["other"] = UNNotificationRequest(identifier: "other", content: content, trigger: nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let records = (0..<55).map { index in
            TravelRecord(start: now.addingTimeInterval(Double(index + 1) * 86400), end: now.addingTimeInterval(Double(index + 2) * 86400), reminderMinutes: 60)
        }
        await value.synchronize(records: records, now: now)
        XCTAssertEqual(client.values.count, 51)
        XCTAssertNotNil(value.message)
        await value.synchronize(records: [], now: now)
        XCTAssertEqual(Set(client.values.keys), ["other"])
    }

    func testDeniedReminderPermissionStillAllowsTripSaveAndKeepsStatusVisible() async throws {
        let directory = folder(); defer { try? FileManager.default.removeItem(at: directory) }
        let client = MemoryTripNotifications(); client.allowed = false
        let reminders = TripReminderStore(client: client)
        let value = TripStore(directory: directory, reminders: reminders)
        try value.unlockForDocumentTests(key: SymmetricKey(size: .bits256))
        let record = TravelRecord(name: "Saved despite notification settings", start: Date().addingTimeInterval(7200), end: Date().addingTimeInterval(10800), reminderMinutes: 60)
        let allowed = await reminders.requestAccess()
        XCTAssertFalse(allowed)
        XCTAssertTrue(value.save(record))
        await reminders.synchronize(records: [record])
        XCTAssertEqual(value.records.first?.id, record.id)
        XCTAssertNotNil(reminders.message)
    }
}
