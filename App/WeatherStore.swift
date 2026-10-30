import SwiftUI
import UIKit
import WeatherKit
import MapKit
import CoreLocation

enum WeatherForecastPeriod: String, CaseIterable, Identifiable {
    case hourly = "Hourly", tomorrow = "Tomorrow", fiveDays = "5 days", week = "7 days"
    var id: String { rawValue }
}

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
        var seen = Set<Date>()
        let lower = now.addingTimeInterval(-3600), upper = now.addingTimeInterval(48 * 3600)
        return Array((hourly ?? []).filter { $0.date >= lower && $0.date < upper }
            .sorted { $0.date < $1.date }.filter { seen.insert($0.date).inserted }.prefix(24))
    }
    func upcomingDays(now: Date = Date()) -> [CachedWeatherDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier ?? "UTC") ?? .gmt
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 8, to: start) else { return [] }
        var seen = Set<Date>()
        // Reject corrupt/out-of-range dates before asking Calendar to interpret them.
        return Array((daily ?? []).filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
            .filter { seen.insert(calendar.startOfDay(for: $0.date)).inserted }.prefix(7))
    }
    func forecastDays(for period: WeatherForecastPeriod, now: Date = Date()) -> [CachedWeatherDay] {
        let days = upcomingDays(now: now)
        switch period {
        case .hourly: return []
        case .fiveDays: return Array(days.prefix(5))
        case .week: return days
        case .tomorrow:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneIdentifier ?? "UTC") ?? .gmt
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return [] }
            return Array(days.filter { calendar.isDate($0.date, inSameDayAs: tomorrow) }.prefix(1))
        }
    }
    func temperatures(_ value: Double) -> String {
        guard let fahrenheit = Int(exactly: (value * 9 / 5 + 32).rounded()),
              let celsius = Int(exactly: value.rounded()) else { return "Unavailable" }
        return "\(fahrenheit)°F / \(celsius)°C"
    }
    static func precipitationPercent(_ chance: Double) -> Int? {
        guard chance.isFinite else { return nil }
        return Int((min(1, max(0, chance)) * 100).rounded())
    }
}
@MainActor final class TripWeatherStore: ObservableObject {
    @Published private(set) var cache: [String: CachedWeather] = [:]
    @Published private(set) var locations: [String: WeatherLocation] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var loading = Set<String>()
    @Published private(set) var attribution: WeatherAttribution?
    @Published private(set) var credit = WeatherCredit.fallback
    @Published private(set) var lightMarkData: Data?
    @Published private(set) var darkMarkData: Data?
    private var cityLoads: [String: Task<Void, Never>] = [:]
    private var attributionLoading = false
    private var attributionAttempt: Date?
    @Published private(set) var lastManualRefresh: [String: Date] = [:]
    @Published private(set) var cacheWriteFailures = Set<String>()
    private let service = WeatherService.shared
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TripNotes/Weather")
        if let data = try? Data(contentsOf: self.directory.appendingPathComponent("forecasts.json")), let saved = try? JSONDecoder().decode([String: CachedWeather].self, from: data) { cache = saved }
        if let data = try? Data(contentsOf: self.directory.appendingPathComponent("locations.json")), let saved = try? JSONDecoder().decode([String: WeatherLocation].self, from: data) { locations = saved }
        if let data = try? Data(contentsOf: self.directory.appendingPathComponent("attribution.json")), let saved = try? JSONDecoder().decode(WeatherCredit.self, from: data) { credit = saved }
        lightMarkData = try? Data(contentsOf: self.directory.appendingPathComponent("mark-light.image"))
        darkMarkData = try? Data(contentsOf: self.directory.appendingPathComponent("mark-dark.image"))
    }
    func loadAttribution() async {
        guard !attributionLoading, !TripConnectionStore.shared.isOffline else { return }
        if let attempt = attributionAttempt, Date().timeIntervalSince(attempt) >= 0,
           Date().timeIntervalSince(attempt) < ((attribution == nil || lightMarkData == nil || darkMarkData == nil) ? 60 : 1800) { return }
        attributionLoading = true; attributionAttempt = Date()
        defer { attributionLoading = false }
        do {
            let value = try await service.attribution
            attribution = value
            credit = WeatherCredit(legalURL: value.legalPageURL, lightMarkURL: value.combinedMarkLightURL, darkMarkURL: value.combinedMarkDarkURL)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(credit) {
                try? data.write(to: directory.appendingPathComponent("attribution.json"), options: [.atomic, .completeFileProtection])
            }
            // Cache the unmodified official marks for both appearances.
            for (name, url) in [("light", value.combinedMarkLightURL), ("dark", value.combinedMarkDarkURL)] {
                guard let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200,
                      UIImage(data: data) != nil else { continue }
                if name == "light" { lightMarkData = data } else { darkMarkData = data }
                try? data.write(to: directory.appendingPathComponent("mark-" + name + ".image"), options: [.atomic, .completeFileProtection])
            }
        } catch {
            // Never remove attribution or the source link on an offline/error path.
        }
    }
    func load(city: City, force: Bool = false) async {
        if let pending = cityLoads[city.id] { await pending.value; return }
        let pending = Task { @MainActor in await self.performLoad(city: city, force: force) }
        cityLoads[city.id] = pending
        await pending.value
        cityLoads[city.id] = nil
    }
    private func performLoad(city: City, force: Bool) async {
        guard !loading.contains(city.id) else { return }
        if TripConnectionStore.shared.isOffline && locations[city.id] == nil { errors[city.id] = "Offline · no saved weather location. Choose and refresh this city before traveling."; return }
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
        if TripConnectionStore.shared.isOffline {
            return Self.savedLocations(matching: query, in: Array(locations.values))
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        let results = response.mapItems.prefix(8).map { WeatherLocation(name: $0.name ?? query, latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude, timeZoneIdentifier: $0.placemark.timeZone?.identifier) }
        for place in results { locations[place.id] = place }
        try persistLocations()
        return results
    }
    func refresh(_ place: WeatherLocation, force: Bool = false) async {
        guard !loading.contains(place.id) else { return }
        loading.insert(place.id); defer { loading.remove(place.id) }
        if force { lastManualRefresh[place.id] = nil }
        if !force, let saved = cache[place.id], saved.hourly != nil, saved.daily != nil, (0..<1800).contains(Date().timeIntervalSince(saved.fetchedAt)), errors[place.id] == nil { return }
        guard !TripConnectionStore.shared.isOffline else { errors[place.id] = "Offline · fresh weather needs internet."; return }
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
            storeForecast(next, for: place, manuallyRefreshed: force)
        } catch { errors[place.id] = "Weather update failed. Check internet and WeatherKit access." }
    }
    func storeForecast(_ forecast: CachedWeather, for place: WeatherLocation, manuallyRefreshed: Bool) {
        cache[place.id] = forecast; errors[place.id] = nil
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(cache).write(to: directory.appendingPathComponent("forecasts.json"), options: [.atomic, .completeFileProtection])
            cacheWriteFailures.removeAll()
        } catch { cacheWriteFailures.insert(place.id) }
        if manuallyRefreshed { lastManualRefresh[place.id] = forecast.fetchedAt }
    }
    func status(for place: WeatherLocation, now: Date = Date(), offline: Bool) -> String {
        guard let saved = cache[place.id] else { return offline ? "Offline · no saved forecast" : "No saved forecast · refresh while connected" }
        if cacheWriteFailures.contains(place.id) { return "Updated for this session · could not save for offline use" }
        if offline { return now.timeIntervalSince(saved.fetchedAt) < 0 || now.timeIntervalSince(saved.fetchedAt) >= 1800 ? "Offline · older forecast; refresh when connected" : "Offline · recently saved forecast" }
        if errors[place.id] != nil { return "Refresh failed · cached forecast" }
        if now.timeIntervalSince(saved.fetchedAt) < 0 || now.timeIntervalSince(saved.fetchedAt) >= 1800 { return "Cached forecast · refresh for current weather" }
        return "Recently updated forecast"
    }
    static func savedLocations(matching query: String, in values: [WeatherLocation]) -> [WeatherLocation] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        return values.filter {
            (query.isEmpty || $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil) && seen.insert($0.id).inserted
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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


#if DEBUG
extension TripWeatherStore {
    func installTutorialWeather(for city: City, celsius: Double) {
        let place = WeatherLocation(name: city.name, latitude: city.name == "Tokyo" ? 35.68 : 34.05, longitude: city.name == "Tokyo" ? 139.69 : -118.24, timeZoneIdentifier: city.timeZoneID)
        locations[city.id] = place
        cache[place.id] = CachedWeather(fetchedAt: Date(), observedAt: Date(), celsius: celsius, high: celsius + 3, low: celsius - 5, condition: "Clear", symbol: "sun.max.fill", hourly: [], daily: [], timeZoneIdentifier: city.timeZoneID)
    }
}
#endif
