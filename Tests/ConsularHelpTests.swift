import XCTest
@testable import UsefulTravelClock

final class ConsularHelpTests: XCTestCase {
    func testDestinationSearchUsesChosenPassportCountry() throws {
        let url = try XCTUnwrap(ConsularMapSearch.url(passportCountry: "US", destination: "Tokyo, Japan"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "maps.apple.com")
        XCTAssertEqual(components.queryItems?.first?.name, "q")
        XCTAssertEqual(components.queryItems?.first?.value, "United States embassy or consulate near Tokyo, Japan")
    }
    func testCurrentLocationIsDelegatedToMapsWithoutStoredCoordinates() throws {
        let url = try XCTUnwrap(ConsularMapSearch.url(passportCountry: "JP", destination: nil))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].value, "Japan embassy or consulate near me")
        XCTAssertEqual(ConsularMapSearch.url(passportCountry: "JP", destination: "  "), url)
    }
    func testInvalidCountryCannotLaunchAndUnicodeLocationsArePreserved() throws {
        XCTAssertNil(ConsularMapSearch.url(passportCountry: "", destination: "Tokyo"))
        XCTAssertNil(ConsularMapSearch.url(passportCountry: "INVALID", destination: "Tokyo"))
        let url = try XCTUnwrap(ConsularMapSearch.url(passportCountry: "FR", destination: "東京 & 京都"))
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "France embassy or consulate near 東京 & 京都")
        XCTAssertTrue(PassportCountry.named("US")!.matches("United States"))
    }
}
