
import WidgetKit
import SwiftUI

@main
struct UsefulTravelClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        UsefulTravelClockSmallWidget()
        UsefulTravelClockMediumWidget()
        UsefulTravelClockLockScreenWidget()
    }
}


struct UsefulTravelClockEntry: TimelineEntry {
    let date: Date
    let cityIDs: [String]
    let homeTimeZoneID: String
}

extension UsefulTravelClockEntry {
    var homeZone: String { homeTimeZoneID }

    func cities(upTo count: Int) -> [City] {
        cityIDs.prefix(count).compactMap { id in clockCityDatabase.first { $0.id == id } }
    }
}


struct UsefulTravelClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsefulTravelClockEntry {
        entry(for: Date(), fallbackIDs: defaultCityIDs)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsefulTravelClockEntry) -> Void) {
        completion(entry(for: Date(), fallbackIDs: defaultCityIDs))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsefulTravelClockEntry>) -> Void) {
        let shared = UserDefaults.usefultravelclockShared
        var ids = defaultCityIDs
        if let data = shared.data(forKey: "usefultravelclock-cities"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            ids = decoded
        }
        let home = shared.string(forKey: "usefultravelclock-home-mode") == "manual"
            ? CitySearch.city(withID: shared.string(forKey: "usefultravelclock-home-city") ?? defaultCityIDs.first ?? "nyc", in: clockCityDatabase)?.timeZoneID ?? TimeZone.current.identifier
            : TimeZone.current.identifier

        var entries: [UsefulTravelClockEntry] = []
        let start = Calendar.current.dateInterval(of: .minute, for: Date())!.start
        for minute in 0..<60 {
            let at = start.addingTimeInterval(TimeInterval(minute * 60))
            entries.append(entry(for: at, fallbackIDs: ids, homeOverride: home))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date, fallbackIDs: [String], homeOverride: String? = nil) -> UsefulTravelClockEntry {
        let shared = UserDefaults.usefultravelclockShared
        var ids = fallbackIDs
        if let data = shared.data(forKey: "usefultravelclock-cities"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            ids = decoded
        }
        let home: String
        if let homeOverride {
            home = homeOverride
        } else if shared.string(forKey: "usefultravelclock-home-mode") == "manual" {
            home = CitySearch.city(withID: shared.string(forKey: "usefultravelclock-home-city") ?? defaultCityIDs.first ?? "nyc", in: clockCityDatabase)?.timeZoneID ?? TimeZone.current.identifier
        } else {
            home = TimeZone.current.identifier
        }
        return UsefulTravelClockEntry(date: date, cityIDs: ids, homeTimeZoneID: home)
    }
}


@available(iOSApplicationExtension 17.0, *)
struct UsefulTravelClockSmallWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "UsefulTravelClockSmallWidget", intent: SmallClockConfiguration.self, provider: SmallClockProvider()) { entry in SmallWidgetView(entry: entry) }
            .configurationDisplayName("Useful Travel Clock")
            .description("Choose one or two cities. Touch and hold, then Edit Widget.")
            .supportedFamilies([.systemSmall])
    }
}

@available(iOSApplicationExtension 17.0, *)
struct UsefulTravelClockMediumWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "UsefulTravelClockMediumWidget", intent: GridClockConfiguration.self, provider: GridClockProvider()) { entry in MediumWidgetView(entry: entry) }
            .configurationDisplayName("World Clock Grid")
            .description("Choose two to six cities and their order with Edit Widget.")
            .supportedFamilies([.systemMedium])
    }
}


struct UsefulTravelClockLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsefulTravelClockLockScreenWidget", provider: UsefulTravelClockProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Lock Screen Clock")
        .description("Circular clock, rectangular time card, or inline city and time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
