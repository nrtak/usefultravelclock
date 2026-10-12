import Foundation

enum WidgetCitySelection {
    static func resolve(_ slots: [String?], available: [String]) -> [String] {
        let valid = Set(available)
        return slots.prefix(6).compactMap { $0 }.filter { valid.contains($0) }
    }
}
