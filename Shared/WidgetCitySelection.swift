import Foundation

/// Explicit positions belong to this widget; empty positions follow the app's saved cities.
enum WidgetCitySelection {
    static func resolve(_ slots: [String?], count: Int, saved: [String], available: [String]) -> [String] {
        let valid = Set(available)
        let limit = max(1, min(6, count))
        let explicit = Set(slots.prefix(limit).compactMap { $0 }.filter { valid.contains($0) })
        var result: [String] = []
        for index in 0..<limit {
            if slots.indices.contains(index), let id = slots[index], valid.contains(id) {
                result.append(id)
            } else if let id = (saved + available).first(where: { valid.contains($0) && !explicit.contains($0) && !result.contains($0) }) {
                result.append(id)
            }
        }
        return result
    }
}
