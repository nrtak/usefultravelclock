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

enum CitySort: String, CaseIterable, Identifiable {
    case custom = "Custom order", name = "City A–Z", timeZone = "Time zone"
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
    @Published var sortOrder: CitySort { didSet { persist() } }
    @Published var favoriteIDs: [String] { didSet { persist() } }
    @Published var nicknames: [String: String] { didSet { persist() } }
    @Published var isEditingCities = false
    @Published private(set) var pendingRemovalIDs: Set<String> = [] { didSet { persist() } }
    @Published private(set) var canUndo = false
    private var undoHistory: [EditState] = []
    private var lastEditState: EditState?
    private var editDepth = 0
    private var restoring = false

    private struct EditState: Equatable {
        var cityIDs: [String]
        var favoriteIDs: [String]
        var nicknames: [String: String]
        var pendingRemovalIDs: Set<String>
        var sortOrder: CitySort
        var theme: ThemeMode
        var homeMode: HomeMode
        var homeCityID: String
        var use24: Bool
        var showAnalog: Bool
        var showDate: Bool
        var showWeekday: Bool
        var showDifference: Bool
    }

    private var editState: EditState {
        EditState(cityIDs: cityIDs, favoriteIDs: favoriteIDs, nicknames: nicknames, pendingRemovalIDs: pendingRemovalIDs,
                  sortOrder: sortOrder, theme: theme, homeMode: homeMode, homeCityID: homeCityID,
                  use24: use24, showAnalog: showAnalog, showDate: showDate,
                  showWeekday: showWeekday, showDifference: showDifference)
    }

    /// Compound actions (replacement, removal, or reordering) undo as one step.
    func edit(_ changes: () -> Void) {
        editDepth += 1
        changes()
        editDepth -= 1
        if editDepth == 0 { persist() }
    }

    func undoLastEdit() {
        guard let previous = undoHistory.popLast() else { return }
        restoring = true
        cityIDs = previous.cityIDs; favoriteIDs = previous.favoriteIDs; nicknames = previous.nicknames
        pendingRemovalIDs = isEditingCities ? previous.pendingRemovalIDs : []
        sortOrder = previous.sortOrder; theme = previous.theme
        homeMode = previous.homeMode; homeCityID = previous.homeCityID
        use24 = previous.use24; showAnalog = previous.showAnalog
        showDate = previous.showDate; showWeekday = previous.showWeekday; showDifference = previous.showDifference
        restoring = false
        lastEditState = editState
        canUndo = !undoHistory.isEmpty
        persist()
    }

    func markCityForRemoval(_ id: String) {
        guard cityIDs.contains(id), !pendingRemovalIDs.contains(id) else { return }
        isEditingCities = true
        pendingRemovalIDs.insert(id)
    }

    func restorePendingCity(_ id: String) { pendingRemovalIDs.remove(id) }

    func finishEditingCities() {
        if !pendingRemovalIDs.isEmpty {
            edit {
                for id in pendingRemovalIDs { removeCity(id) }
                pendingRemovalIDs = []
            }
        }
        isEditingCities = false
    }

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
        sortOrder = CitySort(rawValue: self.defaults.string(forKey: "city-sort") ?? "") ?? .custom
        favoriteIDs = self.defaults.stringArray(forKey: "city-favorites") ?? []
        nicknames = self.defaults.dictionary(forKey: "city-nicknames") as? [String: String] ?? [:]
        cityIDs = Array(cityIDs.prefix(Self.maxCities))
        lastEditState = editState
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist() {
        guard !restoring, editDepth == 0 else { return }
        let current = editState
        if let previous = lastEditState, previous != current {
            undoHistory.append(previous)
            if undoHistory.count > 50 { undoHistory.removeFirst() }
            canUndo = true
        }
        lastEditState = current
        defaults.set(sortOrder.rawValue, forKey: "city-sort")
        defaults.set(favoriteIDs, forKey: "city-favorites")
        defaults.set(nicknames, forKey: "city-nicknames")
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

    func orderedCities(at date: Date = Date()) -> [City] {
        let positions = Dictionary(cityIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return selectedCities.sorted { a, b in
            let ap = favoriteIDs.contains(a.id), bp = favoriteIDs.contains(b.id)
            if ap != bp { return ap }
            switch sortOrder {
            case .custom: return (positions[a.id] ?? 0) < (positions[b.id] ?? 0)
            case .timeZone:
                let ao = TimeZone(identifier: a.timeZoneID)?.secondsFromGMT(for: date) ?? 0
                let bo = TimeZone(identifier: b.timeZoneID)?.secondsFromGMT(for: date) ?? 0
                if ao != bo { return ao < bo }
                fallthrough
            case .name:
                let comparison = a.name.localizedCaseInsensitiveCompare(b.name)
                return comparison == .orderedSame ? a.id < b.id : comparison == .orderedAscending
            }
        }
    }

    func toggleFavorite(_ id: String) {
        if favoriteIDs.contains(id) { favoriteIDs.removeAll { $0 == id } }
        else { favoriteIDs.append(id) }
    }

    func removeCity(_ id: String) {
        edit {
        favoriteIDs.removeAll { $0 == id }
        nicknames.removeValue(forKey: id)
        cityIDs.removeAll { $0 == id }
        }
    }

    @discardableResult func replaceCity(_ id: String, with replacement: String) -> Bool {
        guard replacement != id, !cityIDs.contains(replacement),
              allCities.contains(where: { $0.id == replacement }),
              let index = cityIDs.firstIndex(of: id) else { return false }
        edit {
        if let name = nicknames.removeValue(forKey: id) { nicknames[replacement] = name }
        if favoriteIDs.contains(id) {
            favoriteIDs.removeAll { $0 == id }; favoriteIDs.append(replacement)
        }
        if homeCityID == id { homeCityID = replacement }
        cityIDs[index] = replacement
        }
        return true
    }

    func moveCity(_ id: String, to target: String) {
        guard id != target, favoriteIDs.contains(id) == favoriteIDs.contains(target) else { return }
        var order = orderedCities().map(\.id)
        guard let from = order.firstIndex(of: id), let to = order.firstIndex(of: target) else { return }
        order.remove(at: from); order.insert(id, at: to)
        edit { cityIDs = order; sortOrder = .custom }
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
            removeCity(id)
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
