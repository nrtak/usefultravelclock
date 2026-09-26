// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

//  Useful Travel Clock

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

// MARK: - Shared entry model

struct UsefulTravelClockEntry: TimelineEntry {
    let date: Date
    let cityIDs: [String]
    let homeTimeZoneID: String
}

extension UsefulTravelClockEntry {
    var homeZone: String { homeTimeZoneID }

    func cities(upTo count: Int) -> [City] {
        cityIDs.prefix(count).compactMap { id in CitySearch.city(withID: id, in: cityCatalog) }
    }
}

// MARK: - Timeline provider

/// Reads the city list and home zone from the shared App Group.
struct UsefulTravelClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsefulTravelClockEntry {
        entry(for: Date(), fallbackIDs: defaultCityIDs)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsefulTravelClockEntry) -> Void) {
        completion(entry(for: Date(), fallbackIDs: defaultCityIDs))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsefulTravelClockEntry>) -> Void) {
        // One entry per minute for the next hour, then refresh.
        var entries: [UsefulTravelClockEntry] = []
        let start = Calendar.current.dateInterval(of: .minute, for: Date())?.start ?? Date()
        for minute in 0..<60 {
            let at = start.addingTimeInterval(TimeInterval(minute * 60))
            entries.append(entry(for: at, fallbackIDs: defaultCityIDs))
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
            let id = shared.string(forKey: "usefultravelclock-home-city") ?? defaultCityIDs.first ?? "nyc"
            home = CitySearch.city(withID: id, in: cityCatalog)?.timeZoneID ?? TimeZone.current.identifier
        } else {
            home = TimeZone.current.identifier
        }
        return UsefulTravelClockEntry(date: date, cityIDs: ids, homeTimeZoneID: home)
    }
}

// MARK: - Small widget (single city)

struct UsefulTravelClockSmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsefulTravelClockSmallWidget", provider: UsefulTravelClockProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Useful Travel Clock")
        .description("One city: analog + digital time, date and difference from home.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium widget (six cities, 3 × 2 grid)

struct UsefulTravelClockMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UsefulTravelClockMediumWidget", provider: UsefulTravelClockProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("World Clock Grid")
        .description("Six cities at a glance with differences from home.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Lock screen widgets

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
