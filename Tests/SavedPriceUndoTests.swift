import XCTest
@testable import UsefulTravelClock

final class SavedPriceUndoTests: XCTestCase {
    @MainActor
    func testUndoRestoresPhotoAndOrderWithoutLosingANewerSave() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SavedConversions(directory: folder)
        func entry(_ note: String) -> SavedConversion {
            SavedConversion(id: UUID(), savedAt: Date(), source: "JPY", target: "USD", amount: 1000,
                multiplier: Decimal(string: "0.0067")!, convertedAmount: Decimal(string: "6.7")!,
                rateDates: [], ratesCheckedAt: nil, note: note, photoFilename: nil)
        }
        let first = entry("Tea"), second = entry("Lunch"), newest = entry("Train")
        let photo = Data([1, 2, 3])
        try store.save(first, photo: photo)
        try store.save(second, photo: nil)
        let original = store.items
        store.remove(at: IndexSet(integer: 1))
        XCTAssertTrue(store.canUndo)
        XCTAssertEqual(SavedConversions(directory: folder).items.map(\.id), [second.id])
        try store.save(newest, photo: nil)
        store.undoDelete()
        XCTAssertFalse(store.canUndo)
        XCTAssertEqual(Set(store.items.map(\.id)), Set([first.id, second.id, newest.id]))
        let restored = try XCTUnwrap(store.items.first { $0.id == first.id })
        XCTAssertEqual(restored, original[1])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.photoURL(for: restored))), photo)
        XCTAssertEqual(SavedConversions(directory: folder).items, store.items)
    }
}
