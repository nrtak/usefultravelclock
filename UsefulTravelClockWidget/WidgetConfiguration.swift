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
enum SmallCityCount: Int, AppEnum {
    case one = 1, two = 2
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Number of cities"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.one: "1 city", .two: "2 cities"]
}

@available(iOS 17.0, *)
enum GridCityCount: Int, AppEnum {
    case two = 2, three = 3, four = 4, five = 5, six = 6
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Number of cities"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.two: "2 cities", .three: "3 cities", .four: "4 cities", .five: "5 cities", .six: "6 cities"]
}

@available(iOS 17.0, *)
struct SmallClockConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose cities"
    static var description = IntentDescription("Choose one or two cities. City 1 appears above City 2. Change the city in each position to change their order.")
    @Parameter(title: "Number of cities", default: .one) var count: SmallCityCount
    @Parameter(title: "City 1") var first: ClockCityEntity?
    @Parameter(title: "City 2 (when showing 2)") var second: ClockCityEntity?
}

@available(iOS 17.0, *)
struct GridClockConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose cities and order"
    static var description = IntentDescription("Cities appear left to right, then top to bottom. Change the city in each numbered position to reorder. Positions beyond your selected count are ignored.")
    @Parameter(title: "Number of cities", default: .six) var count: GridCityCount
    @Parameter(title: "City 1") var first: ClockCityEntity?
    @Parameter(title: "City 2") var second: ClockCityEntity?
    @Parameter(title: "City 3") var third: ClockCityEntity?
    @Parameter(title: "City 4") var fourth: ClockCityEntity?
    @Parameter(title: "City 5") var fifth: ClockCityEntity?
    @Parameter(title: "City 6") var sixth: ClockCityEntity?
}

@available(iOS 17.0, *)
struct SmallClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsefulTravelClockEntry { ClockWidgetData.entry(ids: [], count: 1) }
    func snapshot(for configuration: SmallClockConfiguration, in context: Context) async -> UsefulTravelClockEntry {
        ClockWidgetData.entry(ids: [configuration.first?.id, configuration.second?.id], count: configuration.count.rawValue)
    }
    func timeline(for configuration: SmallClockConfiguration, in context: Context) async -> Timeline<UsefulTravelClockEntry> {
        ClockWidgetData.timeline(ids: [configuration.first?.id, configuration.second?.id], count: configuration.count.rawValue)
    }
}

@available(iOS 17.0, *)
struct GridClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UsefulTravelClockEntry { ClockWidgetData.entry(ids: [], count: 6) }
    func snapshot(for configuration: GridClockConfiguration, in context: Context) async -> UsefulTravelClockEntry {
        ClockWidgetData.entry(ids: selection(configuration), count: configuration.count.rawValue)
    }
    func timeline(for configuration: GridClockConfiguration, in context: Context) async -> Timeline<UsefulTravelClockEntry> {
        ClockWidgetData.timeline(ids: selection(configuration), count: configuration.count.rawValue)
    }
    private func selection(_ c: GridClockConfiguration) -> [String?] { [c.first?.id, c.second?.id, c.third?.id, c.fourth?.id, c.fifth?.id, c.sixth?.id] }
}

enum ClockWidgetData {
    static func entry(ids: [String?], count: Int, date: Date = Date()) -> UsefulTravelClockEntry {
        let shared = UserDefaults.usefultravelclockShared
        let saved = shared.data(forKey: "usefultravelclock-cities").flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? defaultCityIDs
        let selected = WidgetCitySelection.resolve(ids, count: count, saved: saved, available: clockCityDatabase.map(\.id))
        let home = shared.string(forKey: "usefultravelclock-home-mode") == "manual"
            ? clockCityDatabase.first { $0.id == shared.string(forKey: "usefultravelclock-home-city") }?.timeZoneID ?? TimeZone.current.identifier
            : TimeZone.current.identifier
        return UsefulTravelClockEntry(date: date, cityIDs: selected, homeTimeZoneID: home)
    }
    static func timeline(ids: [String?], count: Int) -> Timeline<UsefulTravelClockEntry> {
        let start = Calendar.current.dateInterval(of: .minute, for: Date())!.start
        return Timeline(entries: (0..<60).map { entry(ids: ids, count: count, date: start.addingTimeInterval(Double($0 * 60))) }, policy: .atEnd)
    }
}
