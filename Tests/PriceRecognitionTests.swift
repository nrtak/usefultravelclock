import XCTest
@testable import UsefulTravelClock

final class PriceRecognitionTests: XCTestCase {
    func testShoppingPageExcludesProductNumbersAndText() {
        let page = "商品番号 : 486556\nスーパー ノンアイロン\nXS S M L 3XL\nベストセラー\n¥2,990"
        XCTAssertEqual(PriceRecognition.read(page, currency: .named("JPY")).map(\.value), [2990])
        XCTAssertTrue(PriceRecognition.read("486556\n1\n2026\n4.4\nSKU: 123456", currency: .named("JPY")).isEmpty)
    }
    func testDoesNotGuessLettersOrConvertNumberFragments() {
        for text in ["¥2,99O", "$I2.50", "$5O", "B100", "USD 1,2,3", "$12.3456", "3XL", "¥-50"] {
            XCTAssertTrue(PriceRecognition.read(text, currency: .named("USD")).isEmpty, text)
        }
    }
    func testMultiplePricesAndFullWidthJapaneseValues() {
        XCTAssertEqual(PriceRecognition.read("￥２，９９０\n1200円\nJPY 500", currency: .named("JPY")).map(\.value), [2990,1200,500])
        XCTAssertEqual(PriceRecognition.read("$12.50 and $7.25", currency: .named("USD")).map(\.value), [Decimal(string:"12.50")!, Decimal(string:"7.25")!])
        XCTAssertTrue(PriceRecognition.read("USD 12.50", currency: .named("JPY")).isEmpty)
    }
    func testUnmarkedNumbersRequireOptInAndAStandaloneValue() {
        XCTAssertTrue(PriceRecognition.read("2,990", currency: .named("JPY")).isEmpty)
        XCTAssertEqual(PriceRecognition.read("2,990\n12.50", currency: .named("JPY"), includeUnmarked: true).map(\.value), [2990, Decimal(string: "12.50")!])
        XCTAssertTrue(PriceRecognition.read("SKU: 486556\n3XL\nSize 12\n2O90", currency: .named("JPY"), includeUnmarked: true).isEmpty)
    }
    func testPriceLabelsAndDecimalSeparators() {
        XCTAssertEqual(PriceRecognition.read("Price: 12.50\nTotal: 1,234.56", currency: .named("USD")).map(\.value), [Decimal(string:"12.50")!, Decimal(string:"1234.56")!])
        XCTAssertEqual(PriceRecognition.read("€1.234,56\n12,50 EUR", currency: .named("EUR")).map(\.value), [Decimal(string:"1234.56")!, Decimal(string:"12.50")!])
    }
}
