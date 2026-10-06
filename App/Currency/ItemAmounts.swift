import Foundation

enum ItemAmounts {
    static func total(_ entries: [String], subtracting: Set<Int> = [], locale: Locale = .current) -> Decimal? {
        var total: Decimal = 0
        for (index, entry) in entries.enumerated() where !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let amount = Amount.parse(entry, locale: locale) else { return nil }
            total += subtracting.contains(index) ? -amount : amount
        }
        return total
    }

    static func editable(_ value: Decimal, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 16
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}
