import Foundation
import SwiftUI

struct SavedConversion: Codable, Identifiable, Equatable {
    let id: UUID
    let savedAt: Date
    let source: String
    let target: String
    let amount: Decimal
    let multiplier: Decimal
    let convertedAmount: Decimal
    let rateDates: [String]
    let ratesCheckedAt: Date?
    var note: String
    var photoFilename: String?

    var summary: String {
        "\(Amount.format(amount, currency: .named(source))) \(source) → \(Amount.format(convertedAmount, currency: .named(target))) \(target)"
    }
}

@MainActor
final class SavedConversions: ObservableObject {
    @Published private(set) var items: [SavedConversion] = []
    @Published private(set) var loadError: String?
    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("conversions.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SimpleCurrency/Saved")
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return }
        do { items = try JSONDecoder().decode([SavedConversion].self, from: Data(contentsOf: indexURL)) }
        catch { loadError = "Saved conversions couldn’t be opened. Existing files have been preserved. Try reopening the app." }
    }

    func photoURL(for item: SavedConversion) -> URL? {
        guard let name = item.photoFilename, name == "\(item.id.uuidString).jpg" else { return nil }
        return directory.appendingPathComponent(name)
    }

    func save(_ draft: SavedConversion, photo: Data?) throws {
        guard loadError == nil else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var entry = draft
        entry.photoFilename = nil
        let photoURL = directory.appendingPathComponent("\(entry.id.uuidString).jpg")
        if let photo {
            try photo.write(to: photoURL, options: [.atomic, .completeFileProtection])
            entry.photoFilename = photoURL.lastPathComponent
        }
        let next = [entry] + items
        do {
            try JSONEncoder().encode(next).write(to: indexURL, options: [.atomic, .completeFileProtection])
            items = next
        } catch {
            if photo != nil { try? FileManager.default.removeItem(at: photoURL) }
            throw error
        }
    }
}
