import SwiftUI
import CryptoKit
import Security
import LocalAuthentication

struct TravelRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind = "Hotel"
    var name = ""
    var reference = ""
    var from = ""
    var to = ""
    var start = Date()
    var end = Date()
    var note = ""
    var departureTimeZone: String? = nil
    var arrivalTimeZone: String? = nil
    var departureCity: String? = nil
    var arrivalCity: String? = nil
    var bookingReference: String? = nil
    var bookingWebsite: String? = nil
    var traveler: String? = nil
    var reminderMinutes: Int? = nil
    var draftSavedAt: Date? = nil
    func timingLabel(at now: Date) -> String {
        if end <= now { return "Completed" }
        return start <= now ? "Happening now" : "Upcoming"
    }
    func matches(_ query: String) -> Bool {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty || [kind, name, reference, from, to, note, traveler ?? "", bookingReference ?? "", departureCity ?? "", arrivalCity ?? ""].contains { $0.localizedStandardContains(text) }
    }
    var dateWarning: String? {
        guard end < start else { return nil }
        return kind == "Hotel" ? "Check-out is before check-in. Review the dates and both time zones." : "Arrival is before departure. Review the dates and both time zones."
    }
    func zone(start: Bool) -> TimeZone {
        let identifier = start ? departureTimeZone : (arrivalTimeZone ?? (kind == "Hotel" ? departureTimeZone : nil))
        return identifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }
    func timeLabel(start: Bool) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone(start: start)
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        let date = start ? self.start : end
        let identifier = start ? departureTimeZone : (arrivalTimeZone ?? (kind == "Hotel" ? departureTimeZone : nil))
        let label = identifier == nil ? "device time" : (formatter.timeZone.abbreviation(for: date) ?? formatter.timeZone.identifier)
        return formatter.string(from: date) + " · " + label
    }
}
struct TranslationRecord: Codable, Identifiable {
    var id = UUID()
    var text: String
    var note: String
    var image: Data?
    var title: String? = nil
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        return text.isEmpty ? "Saved image" : text
    }
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || [title ?? "", text, note].contains { $0.localizedStandardContains(query) }
    }
}
enum TripSummary {
    static func record(in records: [TravelRecord], at now: Date) -> TravelRecord? {
        // Surface an ongoing stay or journey before later bookings.
        let active = records.filter { $0.start <= now && $0.end > now }
            .min { $0.end < $1.end }
        return active ?? records.filter { $0.start >= now }.min { $0.start < $1.start }
    }
}
@MainActor final class TripStore: ObservableObject {
    @Published var records: [TravelRecord] = []
    @Published private(set) var drafts: [TravelRecord] = []
    @Published private(set) var importDraft: TripImportDraft?
    @Published private(set) var documents: [TripDocument] = []
    @Published var translations: [TranslationRecord] = []
    @Published var unlocked = false
    @Published var loading = false
    @Published var error: String?
    private var key: SymmetricKey?
    private var unlockGeneration = UUID()
    private var reminderGeneration = UUID()
    private var importGeneration = UUID()
    private var draftWritesBlocked = false
    private var translationWritesBlocked = false
    private var deletedTranslation: (record: TranslationRecord, index: Int)?
    @Published private(set) var canUndoTranslationDeletion = false
    private let directory: URL
    private let keyLoader: ((LAContext) async throws -> Data)?
    let reminders: TripReminderStore
    init(directory: URL? = nil, keyLoader: ((LAContext) async throws -> Data)? = nil, reminders: TripReminderStore? = nil) {
        self.keyLoader = keyLoader
        self.reminders = reminders ?? TripReminderStore()
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TripNotes")
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let url = self.directory.appendingPathComponent("translations.json")
            if FileManager.default.fileExists(atPath: url.path) { translations = try JSONDecoder().decode([TranslationRecord].self, from: Data(contentsOf: url)) }
        } catch { translationWritesBlocked = true; self.error = "Saved translations could not be loaded. The original file has been preserved: " + TripSaveError.message(error) }
    }
    func unlock() async {
        guard !loading && !unlocked else { return }
        loading = true; error = nil
        let generation = unlockGeneration
        defer { if generation == unlockGeneration { loading = false } }
        let context = LAContext()
        context.localizedReason = "Preserve your existing travel details after this update"
        do {
            let material: Data
            if let keyLoader { material = try await keyLoader(context) }
            else {
                let allowCreation = !["travel.sealed", "drafts.sealed", "Documents/documents.sealed", "ImportDraft/metadata.sealed"].contains { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }
                material = try await Task.detached { try Self.readKey(context: context, allowCreation: allowCreation) }.value
            }
            guard generation == unlockGeneration else { return }
            let loadedKey = SymmetricKey(data: material)
            let url = directory.appendingPathComponent("travel.sealed")
            var loaded: [TravelRecord] = []
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let clear = try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: loadedKey)
                loaded = try JSONDecoder().decode([TravelRecord].self, from: clear)
            }
            let vault = TripDocumentVault(directory: documentDirectory, key: loadedKey)
            let loadedDocuments = try vault.load()
            var loadedDrafts: [TravelRecord] = []
            var draftError: String?
            draftWritesBlocked = false
            do { loadedDrafts = try readDrafts(using: loadedKey) }
            catch { draftWritesBlocked = true; draftError = "Saved trips loaded, but drafts could not be recovered. The original draft file has been preserved: " + TripSaveError.message(error) }
            records = loaded; documents = loadedDocuments; drafts = loadedDrafts; key = loadedKey; unlocked = true
            do { importDraft = try readImportDraft(using: loadedKey) }
            catch { draftError = "Saved trips loaded, but the document import draft could not be recovered: " + TripSaveError.message(error) }
            error = draftError
            vault.prune(except: loadedDocuments)
            clearDocumentPreviews()
            scheduleReminders(for: loaded)
        } catch { if generation == unlockGeneration { self.error = TripSaveError.message(error) } }
    }
    func lock() { unlockGeneration = UUID(); loading = false; records = []; drafts = []; importDraft = nil; documents = []; key = nil; unlocked = false; clearDocumentPreviews() }
    @discardableResult
    func save(_ record: TravelRecord, clearDraft: Bool = true) -> Bool {
        guard unlocked, let key else { error = "Travel details are locked. Retry loading them before saving."; return false }
        guard record.dateWarning == nil else { error = record.dateWarning; return false }
        do {
            var next = records
            if let index = next.firstIndex(where: { $0.id == record.id }) { next[index] = record } else { next.append(record) }
            let sealed = try AES.GCM.seal(JSONEncoder().encode(next), using: key)
            guard let data = sealed.combined else { throw TripDocumentError.invalidFile }
            try data.write(to: directory.appendingPathComponent("travel.sealed"), options: [.atomic, .completeFileProtection])
            records = next
            error = nil
            if clearDraft { _ = discardDraft(record.id) }
            scheduleReminders(for: next)
            return true
        } catch { self.error = TripSaveError.message(error); return false }
    }
    private func readDrafts(using key: SymmetricKey) throws -> [TravelRecord] {
        let url = directory.appendingPathComponent("drafts.sealed")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let clear = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: url)), using: key)
        return try JSONDecoder().decode([TravelRecord].self, from: clear)
    }
    private func scheduleReminders(for records: [TravelRecord]) {
        let revision = UUID(); reminderGeneration = revision
        Task {
            guard reminderGeneration == revision else { return }
            await reminders.synchronize(records: records)
        }
    }
    @discardableResult
    func saveDraft(_ record: TravelRecord) -> Bool {
        guard unlocked, let key else { return false }
        guard !draftWritesBlocked else { error = "Existing drafts could not be read and have not been replaced. Save your travel entry directly, then retry loading drafts."; return false }
        var saved = record; saved.draftSavedAt = Date()
        var next = drafts.filter { $0.id != record.id }; next.insert(saved, at: 0)
        do { try persistDrafts(next, using: key); drafts = next; return true }
        catch { self.error = "Draft could not be saved. Keep the editor open and retry: " + TripSaveError.message(error); return false }
    }
    @discardableResult
    func discardDraft(_ id: UUID) -> Bool {
        guard unlocked, let key else { return false }
        let next = drafts.filter { $0.id != id }
        guard next.count != drafts.count else { return true }
        do { try persistDrafts(next, using: key); drafts = next; return true }
        catch { self.error = "Could not clear the saved draft: " + TripSaveError.message(error); return false }
    }
    private func persistDrafts(_ values: [TravelRecord], using key: SymmetricKey) throws {
        guard !draftWritesBlocked else { throw CocoaError(.fileReadCorruptFile) }
        guard let bytes = try AES.GCM.seal(JSONEncoder().encode(values), using: key).combined else { throw TripDocumentError.invalidFile }
        try bytes.write(to: directory.appendingPathComponent("drafts.sealed"), options: [.atomic, .completeFileProtection])
    }
    private var importDirectory: URL { directory.appendingPathComponent("ImportDraft") }
    private func readImportDraft(using key: SymmetricKey) throws -> TripImportDraft? {
        let url = importDirectory.appendingPathComponent("metadata.sealed")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let clear = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: url)), using: key)
        return try JSONDecoder().decode(TripImportDraft.self, from: clear)
    }
    func saveImportDraft(_ draft: TripImportDraft, payload: TripDocumentPayload? = nil) throws {
        guard unlocked, let key else { throw TripDocumentError.locked }
        importGeneration = UUID()
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        if let payload {
            guard let bytes = try AES.GCM.seal(JSONEncoder().encode(payload), using: key).combined else { throw TripDocumentError.invalidFile }
            try bytes.write(to: importDirectory.appendingPathComponent(draft.storageID.uuidString + ".sealed"), options: [.atomic, .completeFileProtection])
        }
        guard FileManager.default.fileExists(atPath: importDirectory.appendingPathComponent(draft.storageID.uuidString + ".sealed").path) else { throw TripDocumentError.missing }
        guard let metadata = try AES.GCM.seal(JSONEncoder().encode(draft), using: key).combined else { throw TripDocumentError.invalidFile }
        try metadata.write(to: importDirectory.appendingPathComponent("metadata.sealed"), options: [.atomic, .completeFileProtection])
        importDraft = draft
        let keep = Set(["metadata.sealed", draft.storageID.uuidString + ".sealed"])
        for file in (try? FileManager.default.contentsOfDirectory(at: importDirectory, includingPropertiesForKeys: nil)) ?? [] where file.pathExtension == "sealed" && !keep.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
    }
    func prepareImportDraft(_ draft: TripImportDraft, payload: TripDocumentPayload) async throws {
        guard unlocked, let key else { throw TripDocumentError.locked }
        let revision = unlockGeneration
        let importRevision = UUID(); importGeneration = importRevision
        let directory = importDirectory
        try await Task.detached {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let bytes = try AES.GCM.seal(JSONEncoder().encode(payload), using: key).combined else { throw TripDocumentError.invalidFile }
            try bytes.write(to: directory.appendingPathComponent(draft.storageID.uuidString + ".sealed"), options: [.atomic, .completeFileProtection])
        }.value
        guard unlocked, unlockGeneration == revision else { throw TripDocumentError.locked }
        guard importGeneration == importRevision else { throw CancellationError() }
        try saveImportDraft(draft)
    }
    func importDraftPayload() throws -> TripDocumentPayload {
        guard unlocked, let key, let draft = importDraft else { throw TripDocumentError.locked }
        let bytes = try Data(contentsOf: importDirectory.appendingPathComponent(draft.storageID.uuidString + ".sealed"))
        let clear = try AES.GCM.open(AES.GCM.SealedBox(combined: bytes), using: key)
        let payload = try JSONDecoder().decode(TripDocumentPayload.self, from: clear)
        return try TripDocumentPayload.validate(payload.data, filename: payload.filename)
    }
    func discardImportDraft() throws {
        guard unlocked else { throw TripDocumentError.locked }
        importGeneration = UUID()
        if FileManager.default.fileExists(atPath: importDirectory.path) { try FileManager.default.removeItem(at: importDirectory) }
        importDraft = nil
    }
    func saveTranslation(_ entry: TranslationRecord) -> Bool {
        guard !translationWritesBlocked else { error = "Existing translations could not be read and have not been replaced. Retry opening the app before saving a translation."; return false }
        do {
            var next = translations
            if let index = next.firstIndex(where: { $0.id == entry.id }) { next[index] = entry } else { next.insert(entry, at: 0) }
            try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("translations.json"), options: [.atomic, .completeFileProtection])
            translations = next; error = nil; return true
        } catch { self.error = TripSaveError.message(error); return false }
    }
    @discardableResult
    func deleteTranslation(_ id: UUID) -> Bool {
        guard !translationWritesBlocked, let index = translations.firstIndex(where: { $0.id == id }) else { return false }
        let entry = translations[index]
        var next = translations; next.remove(at: index)
        do {
            try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("translations.json"), options: [.atomic, .completeFileProtection])
            translations = next; deletedTranslation = (entry, index); canUndoTranslationDeletion = true; error = nil
            return true
        } catch { self.error = TripSaveError.message(error); return false }
    }
    @discardableResult
    func undoTranslationDeletion() -> Bool {
        guard !translationWritesBlocked, let deletedTranslation else { return false }
        var next = translations
        guard !next.contains(where: { $0.id == deletedTranslation.record.id }) else { return false }
        next.insert(deletedTranslation.record, at: min(deletedTranslation.index, next.count))
        do {
            try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("translations.json"), options: [.atomic, .completeFileProtection])
            translations = next; self.deletedTranslation = nil; canUndoTranslationDeletion = false; error = nil
            return true
        } catch { self.error = TripSaveError.message(error); return false }
    }
    nonisolated private static func readKey(context: LAContext, allowCreation: Bool) throws -> Data {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.usefultravelclock.app.trip-vault", kSecAttrAccount as String: "travel-key-v2"]
        var query = base
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data { return data }
        guard status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        // Preserve the original protected key. Existing users may be asked once
        // to authorize migration; never replace a key after failed authentication.
        var legacy = query
        legacy[kSecAttrAccount as String] = "travel-key"
        var oldResult: CFTypeRef?
        let legacyStatus = SecItemCopyMatching(legacy as CFDictionary, &oldResult)
        let data: Data
        if legacyStatus == errSecSuccess, let oldData = oldResult as? Data { data = oldData }
        else if legacyStatus == errSecItemNotFound && allowCreation { data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) } }
        else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(legacyStatus)) }
        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(insert as CFDictionary, nil)
        if added == errSecDuplicateItem {
            // A newer unlock may have inserted the device key while this request waited.
            var existing: CFTypeRef?
            let existingStatus = SecItemCopyMatching(query as CFDictionary, &existing)
            guard existingStatus == errSecSuccess, let existingData = existing as? Data else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(existingStatus)) }
            return existingData
        }
        guard added == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(added)) }
        return data
    }
}

extension TripStore {
    private var documentDirectory: URL { directory.appendingPathComponent("Documents") }
    private var previewDirectory: URL { directory.appendingPathComponent("DocumentPreviews") }
    private func documentVault() throws -> TripDocumentVault {
        guard unlocked, let key else { throw TripDocumentError.locked }
        return TripDocumentVault(directory: documentDirectory, key: key)
    }
    func documents(for recordID: UUID) -> [TripDocument] { documents.filter { $0.recordID == recordID } }
    var documentBytes: Int { documents.reduce(0) { $0 + $1.byteCount } }
    func documentAvailable(_ document: TripDocument) -> Bool {
        guard let vault = try? documentVault() else { return false }
        return vault.available(document)
    }
    func readableDocuments() async -> Set<UUID> {
        guard let vault = try? documentVault() else { return [] }
        let generation = unlockGeneration
        let values = documents
        let result = await Task.detached {
            Set(values.compactMap { document -> UUID? in
                (try? vault.data(document)) == nil ? nil : document.id
            })
        }.value
        return unlocked && generation == unlockGeneration ? result : []
    }
    func summaryDocument(at now: Date) -> TripDocument? {
        guard let record = TripSummary.record(in: records, at: now) else { return nil }
        return documents(for: record.id).filter { documentAvailable($0) }.sorted {
            if ($0.kind == .boardingPass) != ($1.kind == .boardingPass) { return $0.kind == .boardingPass }
            return $0.updatedAt > $1.updatedAt
        }.first
    }
    @discardableResult
    func importDocument(_ payload: TripDocumentPayload, name: String, kind: TripDocumentKind, traveler: String, note: String, recordID: UUID?, replacing: UUID? = nil, idempotencyID: UUID? = nil) throws -> TripDocument {
        let vault = try documentVault()
        var next = documents
        let old = (replacing ?? idempotencyID).flatMap { id in next.first { $0.id == id } }
        if replacing != nil && old == nil { throw TripDocumentError.missing }
        var entry = TripDocument(recordID: recordID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), originalFilename: payload.filename, fileExtension: payload.fileExtension, kind: kind, traveler: traveler, note: note, byteCount: payload.data.count)
        if let old { entry.id = old.id } else if let idempotencyID { entry.id = idempotencyID }
        if entry.name.isEmpty { entry.name = URL(fileURLWithPath: payload.filename).deletingPathExtension().lastPathComponent }
        try vault.write(payload, id: entry.storageID)
        if let index = next.firstIndex(where: { $0.id == entry.id }) { next[index] = entry } else { next.insert(entry, at: 0) }
        do { try vault.persist(next) }
        catch { try? vault.remove(entry.storageID); throw error }
        documents = next
        if let old { try? vault.remove(old.storageID) }
        return entry
    }
    func updateDocument(_ document: TripDocument) throws {
        let vault = try documentVault()
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { throw TripDocumentError.missing }
        var entry = documents[index]
        entry.name = document.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.name.isEmpty else { throw TripDocumentError.invalidFile }
        entry.kind = document.kind; entry.traveler = document.traveler; entry.note = document.note; entry.recordID = document.recordID
        var next = documents; next[index] = entry
        try vault.persist(next); documents = next
    }
    func removeDocuments(_ ids: Set<UUID>) throws {
        let vault = try documentVault()
        let next = documents.filter { !ids.contains($0.id) }
        try vault.persist(next); documents = next
        vault.prune(except: next)
        clearDocumentPreviews()
    }
    func removeRecord(_ id: UUID) throws {
        guard let key, unlocked else { throw TripDocumentError.locked }
        // Keep attachments in Documents, unassigned, so deleting a trip cannot silently lose tickets.
        let next = records.filter { $0.id != id }
        guard let sealed = try AES.GCM.seal(JSONEncoder().encode(next), using: key).combined else { throw TripDocumentError.invalidFile }
        try sealed.write(to: directory.appendingPathComponent("travel.sealed"), options: [.atomic, .completeFileProtection])
        records = next
        _ = discardDraft(id)
        scheduleReminders(for: next)
    }
    func previewURL(_ document: TripDocument) throws -> URL {
        let bytes = try documentVault().data(document)
        try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
        let folder = previewDirectory.appendingPathComponent(document.id.uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(document.originalFilename)
        try bytes.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
    func clearDocumentPreviews() { try? FileManager.default.removeItem(at: previewDirectory) }
    #if DEBUG
    func unlockForDocumentTests(key: SymmetricKey) throws {
        self.key = key
        let url = directory.appendingPathComponent("travel.sealed")
        if FileManager.default.fileExists(atPath: url.path) {
            let clear = try AES.GCM.open(AES.GCM.SealedBox(combined: Data(contentsOf: url)), using: key)
            records = try JSONDecoder().decode([TravelRecord].self, from: clear)
        }
        documents = try TripDocumentVault(directory: documentDirectory, key: key).load()
        drafts = try readDrafts(using: key)
        importDraft = try readImportDraft(using: key)
        unlocked = true
    }
    #endif
}

