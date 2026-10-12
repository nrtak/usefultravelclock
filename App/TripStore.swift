import SwiftUI
import CryptoKit
import Security
import LocalAuthentication

struct TravelRecord: Codable, Identifiable {
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
}
@MainActor final class TripStore: ObservableObject {
    @Published var records: [TravelRecord] = []
    @Published private(set) var documents: [TripDocument] = []
    @Published var translations: [TranslationRecord] = []
    @Published var unlocked = false
    @Published var loading = false
    @Published var error: String?
    private var key: SymmetricKey?
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TripNotes")
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
            let url = self.directory.appendingPathComponent("translations.json")
            if FileManager.default.fileExists(atPath: url.path) { translations = try JSONDecoder().decode([TranslationRecord].self, from: Data(contentsOf: url)) }
        } catch { self.error = error.localizedDescription }
    }
    func unlock() async {
        guard !loading && !unlocked else { return }
        loading = true; error = nil
        defer { loading = false }
        let context = LAContext()
        context.localizedReason = "Preserve your existing travel details after this update"
        do {
            let material = try await Task.detached { try Self.readKey(context: context) }.value
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
            records = loaded; documents = loadedDocuments; key = loadedKey; unlocked = true
            vault.prune(except: loadedDocuments)
            clearDocumentPreviews()
        } catch { self.error = error.localizedDescription }
    }
    func lock() { records = []; documents = []; key = nil; unlocked = false; clearDocumentPreviews() }
    func save(_ record: TravelRecord) {
        guard let key else { return }
        do {
            var next = records
            if let index = next.firstIndex(where: { $0.id == record.id }) { next[index] = record } else { next.append(record) }
            let sealed = try AES.GCM.seal(JSONEncoder().encode(next), using: key)
            guard let data = sealed.combined else { return }
            try data.write(to: directory.appendingPathComponent("travel.sealed"), options: [.atomic, .completeFileProtection])
            records = next
        } catch { self.error = error.localizedDescription }
    }
    func saveTranslation(_ entry: TranslationRecord) -> Bool {
        do {
            var next = translations
            if let index = next.firstIndex(where: { $0.id == entry.id }) { next[index] = entry } else { next.insert(entry, at: 0) }
            try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("translations.json"), options: [.atomic, .completeFileProtection])
            translations = next; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    nonisolated private static func readKey(context: LAContext) throws -> Data {
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
        else if legacyStatus == errSecItemNotFound { data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) } }
        else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(legacyStatus)) }
        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let added = SecItemAdd(insert as CFDictionary, nil)
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
    @discardableResult
    func importDocument(_ payload: TripDocumentPayload, name: String, kind: TripDocumentKind, traveler: String, note: String, recordID: UUID?, replacing: UUID? = nil) throws -> TripDocument {
        let vault = try documentVault()
        var next = documents
        let old = replacing.flatMap { id in next.first { $0.id == id } }
        if replacing != nil && old == nil { throw TripDocumentError.missing }
        var entry = TripDocument(recordID: recordID, name: name.trimmingCharacters(in: .whitespacesAndNewlines), originalFilename: payload.filename, fileExtension: payload.fileExtension, kind: kind, traveler: traveler, note: note, byteCount: payload.data.count)
        if let old { entry.id = old.id }
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
        self.key = key; unlocked = true
        documents = try documentVault().load()
    }
    #endif
}

