import SwiftUI
import WeatherKit
import MapKit
import CoreLocation

struct WeatherLocation: Codable, Identifiable, Equatable {
    var id: String { "\(latitude),\(longitude)" }
    let name: String
    let latitude: Double
    let longitude: Double
    var timeZoneIdentifier: String? = nil
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}
struct CachedWeather: Codable {
    let fetchedAt: Date
    let observedAt: Date
    let celsius: Double
    let high: Double?
    let low: Double?
    let condition: String
    let symbol: String
    var hourly: [CachedWeatherHour]? = nil
    var daily: [CachedWeatherDay]? = nil
    var timeZoneIdentifier: String? = nil
    func upcomingHours(now: Date = Date()) -> [CachedWeatherHour] {
        Array((hourly ?? []).filter { $0.date >= now.addingTimeInterval(-3600) }.sorted { $0.date < $1.date }.prefix(24))
    }
    func upcomingDays(now: Date = Date()) -> [CachedWeatherDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier ?? "UTC") ?? .gmt
        let start = calendar.startOfDay(for: now)
        return Array((daily ?? []).filter { $0.date >= start }.sorted { $0.date < $1.date }.prefix(7))
    }
    func temperatures(_ value: Double) -> String { "\(Int((value*9/5+32).rounded()))°F / \(Int(value.rounded()))°C" }
}
@MainActor final class TripWeatherStore: ObservableObject {
    @Published private(set) var cache: [String: CachedWeather] = [:]
    @Published private(set) var locations: [String: WeatherLocation] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var loading = Set<String>()
    @Published private(set) var attribution: WeatherAttribution?
    private let service = WeatherService.shared
    private let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TripNotes/Weather")
    init() {
        if let data = try? Data(contentsOf: directory.appendingPathComponent("forecasts.json")), let saved = try? JSONDecoder().decode([String: CachedWeather].self, from: data) { cache = saved }
        if let data = try? Data(contentsOf: directory.appendingPathComponent("locations.json")), let saved = try? JSONDecoder().decode([String: WeatherLocation].self, from: data) { locations = saved }
    }
    func load(city: City, force: Bool = false) async {
        guard !loading.contains(city.id) else { return }
        loading.insert(city.id); defer { loading.remove(city.id) }
        do {
            let location: WeatherLocation
            if var found = locations[city.id] { found.timeZoneIdentifier = city.timeZoneID; location = found; locations[city.id] = found }
            else {
                let matches = try await search(city.name + ", " + city.country)
                guard let found = matches.first else { throw CocoaError(.fileReadUnknown) }
                var named = found; named.timeZoneIdentifier = city.timeZoneID
                location = named; locations[city.id] = named
                try persistLocations()
            }
            await refresh(location, force: force)
        } catch { errors[city.id] = "Couldn’t find this city. Try location search." }
    }
    func search(_ query: String) async throws -> [WeatherLocation] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(8).map { WeatherLocation(name: $0.name ?? query, latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude, timeZoneIdentifier: $0.placemark.timeZone?.identifier) }
    }
    func refresh(_ place: WeatherLocation, force: Bool = false) async {
        guard !loading.contains(place.id) else { return }
        loading.insert(place.id); defer { loading.remove(place.id) }
        if attribution == nil { attribution = try? await service.attribution }
        if !force, let saved = cache[place.id], saved.hourly != nil, saved.daily != nil, (0..<1800).contains(Date().timeIntervalSince(saved.fetchedAt)) { return }
        do {
            let weather = try await service.weather(for: place.location)
            let current = weather.currentWeather
            let day = weather.dailyForecast.forecast.first
            let next = CachedWeather(fetchedAt: Date(), observedAt: current.date, celsius: current.temperature.converted(to: .celsius).value, high: day?.highTemperature.converted(to: .celsius).value, low: day?.lowTemperature.converted(to: .celsius).value, condition: current.condition.description, symbol: current.symbolName,
                hourly: Array(weather.hourlyForecast.forecast.filter { $0.date >= Date().addingTimeInterval(-3600) }.prefix(24)).map {
                    CachedWeatherHour(date: $0.date, celsius: $0.temperature.converted(to: .celsius).value, symbol: $0.symbolName, condition: $0.condition.description, precipitationChance: $0.precipitationChance)
                },
                daily: Array(weather.dailyForecast.forecast.prefix(7)).map {
                    CachedWeatherDay(date: $0.date, high: $0.highTemperature.converted(to: .celsius).value, low: $0.lowTemperature.converted(to: .celsius).value, symbol: $0.symbolName, condition: $0.condition.description, precipitationChance: $0.precipitationChance)
                }, timeZoneIdentifier: place.timeZoneIdentifier)
            cache[place.id] = next; errors[place.id] = nil
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(cache).write(to: directory.appendingPathComponent("forecasts.json"), options: [.atomic, .completeFileProtection])
        } catch { errors[place.id] = "Weather update failed. Check internet and WeatherKit access." }
    }
    private func persistLocations() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(locations).write(to: directory.appendingPathComponent("locations.json"), options: [.atomic, .completeFileProtection])
    }
}

struct CachedWeatherHour: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let celsius: Double
    let symbol: String
    let condition: String
    let precipitationChance: Double
}
struct CachedWeatherDay: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let high: Double
    let low: Double
    let symbol: String
    let condition: String
    let precipitationChance: Double
}
