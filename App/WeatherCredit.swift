import Foundation

// Persist the URLs separately from WeatherAttribution so a cached forecast has
// its legal link even before WeatherKit is contacted on a later launch.
struct WeatherCredit: Codable {
    let legalURL: URL
    let lightMarkURL: URL?
    let darkMarkURL: URL?
    static let fallback = WeatherCredit(
        legalURL: URL(string: "https://developer.apple.com/weatherkit/data-source-attribution/")!,
        lightMarkURL: nil, darkMarkURL: nil)
}
