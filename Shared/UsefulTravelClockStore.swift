//  Useful Travel Clock

import SwiftUI
import Combine
import WidgetKit

enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case light, dark, system
    var id: String { rawValue }
}

enum HomeMode: String, CaseIterable, Identifiable, Codable {
    case automatic, manual
    var id: String { rawValue }
}

/// App-wide settings, persisted to the shared App Group so widgets read the
/// same city list and home location. Mirrors the web app's localStorage keys.
@MainActor
final class UsefulTravelClockStore: ObservableObject {

    /// App Group identifier — must match the one configured on both targets in Xcode.
    nonisolated static let appGroupID = "group.com.usefultravelclock.app"

    static let maxCities = 10

    @Published var cityIDs: [String] { didSet { persist() } }
    @Published var theme: ThemeMode { didSet { persist() } }
    @Published var homeMode: HomeMode { didSet { persist() } }
    @Published var homeCityID: String { didSet { persist() } }
    @Published var use24: Bool { didSet { persist() } }
    @Published var showAnalog: Bool { didSet { persist() } }
    @Published var showDate: Bool { didSet { persist() } }
    @Published var showWeekday: Bool { didSet { persist() } }
    @Published var showDifference: Bool { didSet { persist() } }
    @Published var scrubHours: Int = 0

    let allCities: [City] = cities

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: UsefulTravelClockStore.appGroupID) ?? .standard
        cityIDs = self.defaults.data(forKey: "usefultravelclock-cities").flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? defaultCityIDs
        theme = ThemeMode(rawValue: self.defaults.string(forKey: "usefultravelclock-theme") ?? "") ?? .light
        homeMode = HomeMode(rawValue: self.defaults.string(forKey: "usefultravelclock-home-mode") ?? "") ?? .automatic
        homeCityID = self.defaults.string(forKey: "usefultravelclock-home-city") ?? (defaultCityIDs.first ?? "nyc")
        use24 = self.defaults.bool(forKey: "use24")
        showAnalog = self.defaults.object(forKey: "showAnalog") as? Bool ?? true
        showDate = self.defaults.object(forKey: "showDate") as? Bool ?? true
        showWeekday = self.defaults.object(forKey: "showWeekday") as? Bool ?? true
        showDifference = self.defaults.object(forKey: "showDifference") as? Bool ?? true
        cityIDs = Array(cityIDs.prefix(Self.maxCities))
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cityIDs) {
            defaults.set(data, forKey: "usefultravelclock-cities")
        }
        defaults.set(theme.rawValue, forKey: "usefultravelclock-theme")
        defaults.set(homeMode.rawValue, forKey: "usefultravelclock-home-mode")
        defaults.set(homeCityID, forKey: "usefultravelclock-home-city")
        defaults.set(use24, forKey: "use24")
        defaults.set(showAnalog, forKey: "showAnalog")
        defaults.set(showDate, forKey: "showDate")
        defaults.set(showWeekday, forKey: "showWeekday")
        defaults.set(showDifference, forKey: "showDifference")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Derived

    var selectedCities: [City] {
        cityIDs.compactMap { id in allCities.first { $0.id == id } }
    }

    var deviceTimeZoneID: String {
        TimeZone.current.identifier
    }

    var homeCity: City? {
        CitySearch.city(withID: homeCityID, in: allCities)
    }

    var homeTimeZoneID: String {
        homeMode == .automatic ? deviceTimeZoneID : (homeCity?.timeZoneID ?? "UTC")
    }

    /// The instant shown, including the time scrubber offset.
    func displayDate(from now: Date) -> Date {
        now.addingTimeInterval(TimeInterval(scrubHours) * 3600)
    }

    // MARK: City selection

    func toggleCity(_ id: String) {
        if cityIDs.contains(id) {
            cityIDs.removeAll { $0 == id }
        } else if cityIDs.count < Self.maxCities {
            cityIDs.append(id)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// Lightweight snapshot the widgets read — plain values only, no SwiftUI.
struct WidgetSnapshot: Codable {
    var cityIDs: [String]
    var homeTimeZoneID: String
    var homeMode: HomeMode
    var theme: ThemeMode

    @MainActor
    static func current(from store: UsefulTravelClockStore) -> WidgetSnapshot {
        WidgetSnapshot(
            cityIDs: store.cityIDs,
            homeTimeZoneID: store.homeTimeZoneID,
            homeMode: store.homeMode,
            theme: store.theme
        )
    }
}

extension UserDefaults {
    /// The same App Group container the widget extension reads.
    static var usefultravelclockShared: UserDefaults {
        UserDefaults(suiteName: UsefulTravelClockStore.appGroupID) ?? .standard
    }
}
