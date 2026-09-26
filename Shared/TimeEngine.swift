// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

//  Useful Travel Clock

import Foundation

/// Mirrors the web app's `src/lib/time.ts`.
struct ZonedTime: Equatable {
    /// "05:00"
    let hm: String
    /// "pm" / "am"
    let period: String
    /// "Friday, 18 September"
    let date: String
    /// Local hour 0-23 (fractional) in that zone.
    let hourFloat: Double
    let hour24: Int
    let minute: Int
}

enum DayPhase: CaseIterable {
    case day, afternoon, dusk, evening, night
}

enum TimeEngine {

    static func zone(_ id: String) -> TimeZone {
        TimeZone(identifier: id) ?? .current
    }

    static func zonedTime(_ date: Date, timeZoneID: String) -> ZonedTime {
        let tz = zone(timeZoneID)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hour24 = comps.hour ?? 0
        let minute = comps.minute ?? 0

        let displayHour = hour24 % 12 == 0 ? 12 : hour24 % 12
        let hm = String(format: "%02d:%02d", displayHour, minute)
        let period = hour24 < 12 ? "am" : "pm"

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.timeZone = tz
        dateFmt.dateFormat = "EEEE, d MMMM"
        let dateLabel = dateFmt.string(from: date)

        return ZonedTime(
            hm: hm,
            period: period,
            date: dateLabel,
            hourFloat: Double(hour24) + Double(minute) / 60,
            hour24: hour24,
            minute: minute
        )
    }

    /// Offset in minutes of `timeZoneID` from GMT at `date` (DST-safe).
    static func zoneOffsetMinutes(_ date: Date, timeZoneID: String) -> Int {
        zone(timeZoneID).secondsFromGMT(for: date) / 60
    }

    /// Offset in minutes of `timeZoneID` relative to the home zone at `date`.
    static func timeDifferenceMinutes(_ date: Date, timeZoneID: String, homeTimeZoneID: String) -> Int {
        zoneOffsetMinutes(date, timeZoneID: timeZoneID)
            - zoneOffsetMinutes(date, timeZoneID: homeTimeZoneID)
    }

    /// "Home", "3 hours ahead", "1 hour 30 minutes behind" — spelled out, app style.
    static func formatDifference(_ minutes: Int) -> String {
        guard minutes != 0 else { return "Home" }
        let absolute = abs(minutes)
        let hours = absolute / 60
        let remainder = absolute % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
        if remainder > 0 { parts.append("\(remainder) \(remainder == 1 ? "minute" : "minutes")") }
        return parts.joined(separator: " ") + (minutes > 0 ? " ahead" : " behind")
    }

    /// Widget style: "+5 hrs", "-3 hrs", "+9 hrs 30 mins", "Home".
    static func formatDifferenceCompact(_ minutes: Int) -> String {
        guard minutes != 0 else { return "Home" }
        let absolute = abs(minutes)
        let hours = absolute / 60
        let remainder = absolute % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hrs") }
        if remainder > 0 { parts.append("\(remainder) mins") }
        return (minutes > 0 ? "+" : "-") + parts.joined(separator: " ")
    }

    static func dayPhase(_ hourFloat: Double) -> DayPhase {
        switch hourFloat {
        case 7..<12: return .day
        case 12..<16: return .afternoon
        case 16..<18: return .dusk
        case 18..<22: return .evening
        default: return .night
        }
    }

    /// Widget style date: "Fri, Sep 18".
    static func compactDate(_ date: Date, timeZoneID: String) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = zone(timeZoneID)
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: date)
    }

    // MARK: - Converter input/output ("yyyy-MM-dd" + "HH:mm" in a zone)

    /// Resolves Gregorian wall-clock input without normalizing invalid dates or
    /// skipped local times. Repeated times default to their first occurrence.
    static func fromZonedInput(
        day: String, time: String, timeZoneID: String,
        repeatedTimePolicy: Calendar.RepeatedTimePolicy = .first
    ) -> Date? {
        guard day.range(of: #"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"#, options: .regularExpression) != nil,
              time.range(of: #"^[0-9]{2}:[0-9]{2}$"#, options: .regularExpression) != nil,
              let tz = TimeZone(identifier: timeZoneID) else { return nil }
        let dayParts = day.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard dayParts.count == 3, timeParts.count == 2 else { return nil }
        let (year, month, dayNumber) = (dayParts[0], dayParts[1], dayParts[2])
        let (hour, minute) = (timeParts[0], timeParts[1])
        guard (1...9999).contains(year), (1...12).contains(month),
              (1...31).contains(dayNumber), (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: dayNumber,
                                        hour: hour, minute: minute, second: 0)
        guard let target = utc.date(from: components) else { return nil }
        let validated = toZonedInput(target, timeZoneID: "UTC")
        guard validated.day == day, validated.time == time else { return nil }

        var local = Calendar(identifier: .gregorian)
        local.timeZone = tz
        // Start before either occurrence, including zones across the date line.
        guard let instant = local.nextDate(
            after: target.addingTimeInterval(-48 * 3600), matching: components,
            matchingPolicy: .strict, repeatedTimePolicy: repeatedTimePolicy,
            direction: .forward
        ) else { return nil }
        let resolved = toZonedInput(instant, timeZoneID: timeZoneID)
        guard resolved.day == day, resolved.time == time else { return nil }
        return instant
    }

    /// Current wall-clock in a zone as converter inputs.
    static func toZonedInput(_ date: Date, timeZoneID: String) -> (day: String, time: String) {
        let tz = zone(timeZoneID)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let day = String(format: "%04d-%02d-%02d", comps.year ?? 2026, comps.month ?? 1, comps.day ?? 1)
        let time = String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
        return (day, time)
    }

    /// "America · Los Angeles" style readable zone name.
    static func readableZone(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "/", with: " · ")
    }
}
