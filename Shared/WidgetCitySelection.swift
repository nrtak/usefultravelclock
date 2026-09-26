import Foundation

/// Empty or unavailable positions are omitted without filling from the app list.
enum WidgetCitySelection {
    static func resolve(_ slots: [String?], available: [String]) -> [String] {
        let valid = Set(available)
        return slots.prefix(6).compactMap { $0 }.filter { valid.contains($0) }
    }
}
