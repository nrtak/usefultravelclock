import XCTest
@testable import UsefulTravelClock
final class UnitConversionTests: XCTestCase {
    func testBothDirectionsAndTemperatureOffsets() throws {
        let km = try XCTUnwrap(UnitConversion.convert(10, from: .named("mi"), to: .named("km")))
        XCTAssertEqual(km, 16.09344, accuracy: 0.0000001)
        XCTAssertEqual(try XCTUnwrap(UnitConversion.convert(km, from: .named("km"), to: .named("mi"))), 10, accuracy: 0.0000001)
        XCTAssertEqual(try XCTUnwrap(UnitConversion.convert(-40, from: .named("c"), to: .named("f"))), -40, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(UnitConversion.convert(32, from: .named("f"), to: .named("c"))), 0, accuracy: 0.000001)
        XCTAssertNil(UnitConversion.convert(-274, from: .named("c"), to: .named("f")))
        XCTAssertNil(UnitConversion.convert(5, from: .named("mi"), to: .named("kg")))
    }
    func testVolumeStandardsAreDistinctAndInvalidInputRejected() throws {
        XCTAssertEqual(try XCTUnwrap(UnitConversion.convert(1, from: .named("galUS"), to: .named("l"))), 3.785411784, accuracy: 0.000000001)
        XCTAssertEqual(try XCTUnwrap(UnitConversion.convert(1, from: .named("galUK"), to: .named("l"))), 4.54609, accuracy: 0.000000001)
        XCTAssertNil(UnitConversion.parse("1,000", locale: Locale(identifier: "en_US")))
        XCTAssertEqual(UnitConversion.parse("-12,5", locale: Locale(identifier: "fr_FR")), -12.5)
    }
    func testRecognitionRequiresUnits() {
        XCTAssertTrue(UnitConversion.readings("Price 20; quantity 5").isEmpty)
        let readings = UnitConversion.readings("Weight 5 kg and distance 10 km, -20°C")
        XCTAssertEqual(Set(readings.map { $0.unit.id }), Set(["kg", "km", "c"]))
        XCTAssertEqual(readings.first { $0.unit.id == "c" }?.value, -20)
    }
    @MainActor func testSavedValuesPhotoAndNotesSurviveReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("units.json")
        let store = UnitConversionStore(url: url)
        XCTAssertTrue(store.save(SavedUnitConversion(source: "kg", target: "lb", sourceValue: 5, targetValue: 11.0231131092, note: "Bag", image: Data([1,2,3]))))
        let reopened = UnitConversionStore(url: url)
        XCTAssertEqual(reopened.entries.first?.sourceValue, 5)
        XCTAssertEqual(reopened.entries.first?.note, "Bag")
        XCTAssertEqual(reopened.entries.first?.image, Data([1,2,3]))
    }
    @MainActor func testUndoDeletePreservesPhotoAndNewSaves() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("units.json")
        let store = UnitConversionStore(url: url)
        let first = SavedUnitConversion(source: "kg", target: "lb", sourceValue: 5, targetValue: 11, note: "Bag", image: Data([1,2,3]))
        XCTAssertTrue(store.save(first))
        store.remove(at: IndexSet(integer: 0))
        XCTAssertTrue(store.canUndo)
        XCTAssertTrue(store.entries.isEmpty)
        let second = SavedUnitConversion(source: "mi", target: "km", sourceValue: 1, targetValue: 1.6, note: "Walk", image: nil)
        XCTAssertTrue(store.save(second))
        store.undoDelete()
        XCTAssertFalse(store.canUndo)
        XCTAssertEqual(Set(store.entries.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(UnitConversionStore(url: url).entries.first { $0.id == first.id }?.image, first.image)
        store.undoDelete()
        XCTAssertEqual(store.entries.count, 2)
    }
}
