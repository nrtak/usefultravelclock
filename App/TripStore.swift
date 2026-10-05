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
            records = loaded; key = loadedKey; unlocked = true
        } catch { self.error = error.localizedDescription }
    }
    func lock() { records = []; key = nil; unlocked = false }
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
