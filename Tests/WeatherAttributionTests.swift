import XCTest
@testable import UsefulTravelClock

final class WeatherAttributionTests: XCTestCase {
    @MainActor
    func testSourcesRemainAvailableBeforeAnyNetworkRequest() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fresh = TripWeatherStore(directory: directory)
        XCTAssertEqual(fresh.credit.legalURL, WeatherCredit.fallback.legalURL)
        XCTAssertEqual(fresh.credit.legalURL.scheme, "https")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cached = WeatherCredit(legalURL: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!, lightMarkURL: nil, darkMarkURL: nil)
        try JSONEncoder().encode(cached).write(to: directory.appendingPathComponent("attribution.json"))
        let reopened = TripWeatherStore(directory: directory)
        XCTAssertNil(reopened.attribution)
        XCTAssertEqual(reopened.credit.legalURL, cached.legalURL)
        try Data("damaged cache".utf8).write(to: directory.appendingPathComponent("attribution.json"))
        XCTAssertEqual(TripWeatherStore(directory: directory).credit.legalURL, WeatherCredit.fallback.legalURL)
    }
}
