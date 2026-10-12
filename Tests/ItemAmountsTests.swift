import XCTest
@testable import UsefulTravelClock

final class ItemAmountsTests: XCTestCase {
    private let us = Locale(identifier: "en_US")
    func testShoppingTotalAndConversion() {
        let total = ItemAmounts.total(["1500", "800", "2200"], locale: us)
        XCTAssertEqual(total, 4500)
        let rates = RateSnapshot(fetchedAt: Date(), rows: [Rate(date: "2026-09-30", base: "USD", quote: "JPY", rate: 150)])
        let converted = total! * rates.multiplier(from: "JPY", to: "USD")!
        XCTAssertEqual(Amount.format(converted, currency: .named("USD"), locale: us), "30.00")
    }
    func testDecimalPricesAvoidBinaryRounding() {
        XCTAssertEqual(ItemAmounts.total(["0.1", "0.2"], locale: us), Decimal(string: "0.3"))
    }
    func testDiscountsAndMultipleSubtractions() {
        XCTAssertEqual(ItemAmounts.total(["100", "50", "20", "5"], subtracting: [2, 3], locale: us), 125)
        XCTAssertEqual(ItemAmounts.total(["0.30", "0.10"], subtracting: [1], locale: us), Decimal(string: "0.20"))
        XCTAssertEqual(ItemAmounts.total(["10", "10"], subtracting: [1], locale: us), 0)
        XCTAssertEqual(ItemAmounts.total(["10", "20"], subtracting: [1], locale: us), -10)
        XCTAssertNil(ItemAmounts.total(["10", "invalid"], subtracting: [1], locale: us))
    }
    func testInvalidItemsDoNotSilentlyDisappear() {
        XCTAssertNil(ItemAmounts.total(["120", "1,500"], locale: us))
        XCTAssertNil(ItemAmounts.total(["120", "-5"], locale: us))
        XCTAssertEqual(ItemAmounts.total(["120", "", "  "], locale: us), 120)
    }
    func testLocaleAndEditableRoundTrip() {
        let locale = Locale(identifier: "de_DE")
        let total = ItemAmounts.total(["1,50", "2,25"], locale: locale)!
        XCTAssertEqual(total, Decimal(string: "3.75"))
        XCTAssertEqual(Amount.parse(ItemAmounts.editable(total, locale: locale), locale: locale), total)
    }
}
