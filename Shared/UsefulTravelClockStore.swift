// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

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
    @Published var scrubHours: Int = 0

    let allCities: [City] = cities

    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        let storage = defaults ?? .usefultravelclockShared
        self.defaults = storage
        let savedIDs = storage.data(forKey: "usefultravelclock-cities")
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? defaultCityIDs
        cityIDs = Array(savedIDs.prefix(Self.maxCities))
        theme = ThemeMode(rawValue: storage.string(forKey: "usefultravelclock-theme") ?? "") ?? .light
        homeMode = HomeMode(rawValue: storage.string(forKey: "usefultravelclock-home-mode") ?? "") ?? .automatic
        homeCityID = storage.string(forKey: "usefultravelclock-home-city") ?? (defaultCityIDs.first ?? "nyc")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cityIDs) {
            defaults.set(data, forKey: "usefultravelclock-cities")
        }
        defaults.set(theme.rawValue, forKey: "usefultravelclock-theme")
        defaults.set(homeMode.rawValue, forKey: "usefultravelclock-home-mode")
        defaults.set(homeCityID, forKey: "usefultravelclock-home-city")
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
