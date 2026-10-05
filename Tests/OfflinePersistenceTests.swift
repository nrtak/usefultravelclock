import XCTest
import UIKit
@testable import UsefulTravelClock

final class OfflinePersistenceTests: XCTestCase {
    @MainActor
    func testNotesAndRealPhotosSurviveReopeningLocalStores() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 60)).image { context in
            UIColor.systemGreen.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 100, height: 60))
        }
        let photo = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let unitsURL = directory.appendingPathComponent("units.json")
        let units = UnitConversionStore(url: unitsURL)
        let unit = SavedUnitConversion(source: "kg", target: "lb", sourceValue: 10, targetValue: 22.0462, note: "Suitcase before departure", image: photo)
        XCTAssertTrue(units.save(unit))
        let reopenedUnits = UnitConversionStore(url: unitsURL)
        let restoredUnit = try XCTUnwrap(reopenedUnits.entries.first)
        XCTAssertEqual(restoredUnit.id, unit.id)
        XCTAssertEqual(restoredUnit.sourceValue, 10)
        XCTAssertEqual(restoredUnit.note, unit.note)
        XCTAssertEqual(restoredUnit.image, photo)
        XCTAssertNotNil(restoredUnit.image.flatMap { UIImage(data: $0) })

        let priceDirectory = directory.appendingPathComponent("Prices")
        let prices = SavedConversions(directory: priceDirectory)
        let price = SavedConversion(id: UUID(), savedAt: Date(), source: "JPY", target: "USD", amount: 500, multiplier: Decimal(string: "0.00633232")!, convertedAmount: Decimal(string: "3.16616")!, rateDates: ["2026-10-05"], ratesCheckedAt: Date(), note: "Coffee at the station café", photoFilename: nil)
        try prices.save(price, photo: photo)
        XCTAssertEqual(prices.lastSavedID, price.id)
        let reopenedPrices = SavedConversions(directory: priceDirectory)
        XCTAssertNil(reopenedPrices.lastSavedID)
        let restoredPrice = try XCTUnwrap(reopenedPrices.items.first)
        XCTAssertEqual(restoredPrice.note, price.note)
        XCTAssertEqual(restoredPrice.convertedAmount, price.convertedAmount)
        let photoURL = try XCTUnwrap(reopenedPrices.photoURL(for: restoredPrice))
        XCTAssertEqual(try Data(contentsOf: photoURL), photo)
        XCTAssertNotNil(UIImage(contentsOfFile: photoURL.path))

        let tripDirectory = directory.appendingPathComponent("Trip")
        let trip = TripStore(directory: tripDirectory)
        let translation = TranslationRecord(text: "Un café, por favor.", note: "Ordering at the café", image: photo)
        XCTAssertTrue(trip.saveTranslation(translation))
        let reopenedTrip = TripStore(directory: tripDirectory)
        let restoredTranslation = try XCTUnwrap(reopenedTrip.translations.first)
        XCTAssertEqual(restoredTranslation.id, translation.id)
        XCTAssertEqual(restoredTranslation.text, translation.text)
        XCTAssertEqual(restoredTranslation.note, translation.note)
        XCTAssertEqual(restoredTranslation.image, photo)
        XCTAssertNotNil(restoredTranslation.image.flatMap { UIImage(data: $0) })
    }
}
