import XCTest
@testable import UsefulTravelClock

final class CitySearchTests: XCTestCase {
    func testClockLocationIncludesUSStateAndAlwaysKeepsCountry() throws {
        let la = try XCTUnwrap(cities.first { $0.id == "lax" })
        let tokyo = try XCTUnwrap(cities.first { $0.id == "tyo" })
        let singapore = try XCTUnwrap(cities.first { $0.id == "sin" })
        XCTAssertEqual(la.clockLocationLabel, "California, USA")
        XCTAssertEqual(tokyo.clockLocationLabel, "Japan")
        XCTAssertEqual(singapore.clockLocationLabel, "Singapore")
        let canadian = City(id: "test", name: "Example", country: "Canada", region: "CA", timeZoneID: "America/Toronto")
        XCTAssertEqual(canadian.clockLocationLabel, "Canada", "US state names must not be applied to other countries")
        let missingState = City(id: "test", name: "Example", country: "USA", timeZoneID: "America/New_York")
        XCTAssertEqual(missingState.clockLocationLabel, "USA", "Do not infer a state from its time zone")
        let custom = City(id: "test", name: "Example", country: "United States", region: " ca ", timeZoneID: "America/Los_Angeles")
        XCTAssertEqual(custom.clockLocationLabel, "California, United States")
    }

    func testStateNamesAndAbbreviationsFindTheirCities() {
        let california = Set(CitySearch.search(" California ", in: cities).map(\.id))
        XCTAssertTrue(Set(["lax", "sfo", "san"]).isSubset(of: california))
        let texas = Set(CitySearch.search("texas", in: cities).map(\.id))
        XCTAssertTrue(Set(["dfw", "hou", "aus"]).isSubset(of: texas))
        let abbreviated = CitySearch.search("ca", in: cities)
        XCTAssertEqual(Set(abbreviated.prefix(3).map(\.id)), Set(["lax", "sfo", "san"]))
    }

    func testStateAliasesOnlyApplyToUSCities() {
        let outsideUS = City(id: "test", name: "Example", country: "Canada", region: "CA", timeZoneID: "America/Toronto")
        XCTAssertTrue(CitySearch.search("California", in: [outsideUS]).isEmpty)
        XCTAssertTrue(CitySearch.search("Washington", in: cities).contains { $0.id == "sea" })
    }

    func testCityAndAirportSearchStillWork() {
        XCTAssertTrue(CitySearch.search("Tokyo", in: cities).contains { $0.id == "tyo" })
        XCTAssertTrue(CitySearch.search("LAX", in: cities).contains { $0.id == "lax" })
        XCTAssertFalse(CitySearch.search("", in: cities).isEmpty)
    }
}
