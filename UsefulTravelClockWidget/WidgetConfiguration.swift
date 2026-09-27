import AppIntents
import WidgetKit

@available(iOS 17.0, *)
struct ClockCityEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    static var defaultQuery = ClockCityQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    init(city: City) { id = city.id; name = city.shortLabel }
}

@available(iOS 17.0, *)
struct ClockCityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ClockCityEntity] {
        identifiers.compactMap { id in clockCityDatabase.first { $0.id == id }.map(ClockCityEntity.init) }
    }
    func suggestedEntities() async throws -> [ClockCityEntity] {
        let shared = UserDefaults.usefultravelclockShared
        let ids = shared.data(forKey: "usefultravelclock-cities").flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? defaultCityIDs
        return try await entities(for: ids)
    }
    func entities(matching string: String) async throws -> [ClockCityEntity] {
        CitySearch.search(string, in: clockCityDatabase).map(ClockCityEntity.init)
    }
}

@available(iOS 17.0, *)
struct SmallClockConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose cities"
    static var description = IntentDescription("Choose up to two cities. Leave a position blank to omit it. City 1 appears above City 2.")
    @Parameter(title: "City 1") var first: ClockCityEntity?
    @Parameter(title: "City 2") var second: ClockCityEntity?
}

@available(iOS 17.0, *)
struct GridClockConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose cities and order"
    static var description = IntentDescription("Choose up to six cities in the Cities list. Reorder the list to arrange the grid left to right, then top to bottom.")
    @Parameter(title: "Cities", default: [], size: IntentCollectionSize(min: 0, max: 6))
    var selectedCities: [ClockCityEntity]
}

@available(iOS 17.0, *)
struct SmallClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsefulTravelClockEntry { ClockWidgetData.entry(ids: Array(defaultCityIDs.prefix(1)).map { Optional($0) }) }
    func snapshot(for configuration: SmallClockConfiguration, in context: Context) async -> UsefulTravelClockEntry {
        ClockWidgetData.entry(ids: [configuration.first?.id, configuration.second?.id])
    }
    func timeline(for configuration: SmallClockConfiguration, in context: Context) async -> Timeline<UsefulTravelClockEntry> {
        ClockWidgetData.timeline(ids: [configuration.first?.id, configuration.second?.id])
    }
}

@available(iOS 17.0, *)
struct GridClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsefulTravelClockEntry { ClockWidgetData.entry(ids: Array(defaultCityIDs.prefix(3)).map { Optional($0) }) }
    func snapshot(for configuration: GridClockConfiguration, in context: Context) async -> UsefulTravelClockEntry {
        ClockWidgetData.entry(ids: selection(configuration))
    }
    func timeline(for configuration: GridClockConfiguration, in context: Context) async -> Timeline<UsefulTravelClockEntry> {
        ClockWidgetData.timeline(ids: selection(configuration))
    }
    private func selection(_ c: GridClockConfiguration) -> [String?] { c.selectedCities.prefix(6).map { Optional($0.id) } }
}

enum ClockWidgetData {
    static func entry(ids: [String?], date: Date = Date()) -> UsefulTravelClockEntry {
        let shared = UserDefaults.usefultravelclockShared
        let selected = WidgetCitySelection.resolve(ids, available: clockCityDatabase.map(\.id))
        let home = shared.string(forKey: "usefultravelclock-home-mode") == "manual"
            ? clockCityDatabase.first { $0.id == shared.string(forKey: "usefultravelclock-home-city") }?.timeZoneID ?? TimeZone.current.identifier
            : TimeZone.current.identifier
        return UsefulTravelClockEntry(date: date, cityIDs: selected, homeTimeZoneID: home)
    }
    static func timeline(ids: [String?]) -> Timeline<UsefulTravelClockEntry> {
        let start = Calendar.current.dateInterval(of: .minute, for: Date())!.start
        return Timeline(entries: (0..<60).map { entry(ids: ids, date: start.addingTimeInterval(Double($0 * 60))) }, policy: .atEnd)
    }
}
