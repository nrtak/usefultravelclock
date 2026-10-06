import Foundation

enum UnitCategory: String, CaseIterable, Identifiable, Codable {
    case temperature = "Temperature", distance = "Distance", weight = "Weight", volume = "Volume"
    var id: String { rawValue }
    var icon: String {
        switch self { case .temperature: return "thermometer.medium"; case .distance: return "ruler"; case .weight: return "scalemass"; case .volume: return "drop" }
    }
}
struct TravelUnit: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let category: UnitCategory
    let scale: Double
    let offset: Double
    let aliases: [String]
    init(_ id: String, _ name: String, _ symbol: String, _ category: UnitCategory, _ scale: Double, _ offset: Double = 0, _ aliases: [String] = []) {
        self.id = id; self.name = name; self.symbol = symbol; self.category = category; self.scale = scale; self.offset = offset; self.aliases = aliases
    }
    static let all: [TravelUnit] = [
        .init("c", "Celsius", "°C", .temperature, 1, 273.15, ["celsius", "°c"]),
        .init("f", "Fahrenheit", "°F", .temperature, 5/9, 459.67*5/9, ["fahrenheit", "°f"]),
        .init("k", "Kelvin", "K", .temperature, 1, 0, ["kelvin", "k"]),
        .init("mi", "Miles", "mi", .distance, 1609.344, 0, ["miles", "mile", "mi"]),
        .init("km", "Kilometers", "km", .distance, 1000, 0, ["kilometers", "kilometres", "km"]),
        .init("m", "Meters", "m", .distance, 1, 0, ["meters", "metres", "m"]),
        .init("cm", "Centimeters", "cm", .distance, 0.01, 0, ["centimeters", "centimetres", "cm"]),
        .init("in", "Inches", "in", .distance, 0.0254, 0, ["inches", "inch", "in"]),
        .init("ft", "Feet", "ft", .distance, 0.3048, 0, ["feet", "foot", "ft"]),
        .init("yd", "Yards", "yd", .distance, 0.9144, 0, ["yards", "yard", "yd"]),
        .init("kg", "Kilograms", "kg", .weight, 1, 0, ["kilograms", "kg"]),
        .init("g", "Grams", "g", .weight, 0.001, 0, ["grams", "g"]),
        .init("lb", "Pounds", "lb", .weight, 0.45359237, 0, ["pounds", "lbs", "lb"]),
        .init("oz", "Ounces (weight)", "oz", .weight, 0.028349523125, 0, ["ounces", "oz"]),
        .init("l", "Liters", "L", .volume, 1, 0, ["liters", "litres", "l"]),
        .init("ml", "Milliliters", "mL", .volume, 0.001, 0, ["milliliters", "millilitres", "ml"]),
        .init("galUS", "Gallons (US)", "US gal", .volume, 3.785411784),
        .init("galUK", "Gallons (Imperial)", "Imp gal", .volume, 4.54609),
        .init("flozUS", "Fluid ounces (US)", "US fl oz", .volume, 0.0295735295625),
        .init("flozUK", "Fluid ounces (Imperial)", "Imp fl oz", .volume, 0.0284130625)
    ]
    static func named(_ id: String) -> TravelUnit { all.first { $0.id == id } ?? all[0] }
}
enum UnitConversion {
    static func convert(_ value: Double, from: TravelUnit, to: TravelUnit) -> Double? {
        guard value.isFinite, from.category == to.category else { return nil }
        let base = value * from.scale + from.offset
        guard from.category == .temperature ? base >= -0.0000001 : value >= 0 else { return nil }
        let result = (base - to.offset) / to.scale
        return result.isFinite ? result : nil
    }
    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard normalized.range(of: #"^-?\d+(?:\.\d*)?$"#, options: .regularExpression) != nil, let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
    static func format(_ value: Double, grouping: Bool = false) -> String {
        let f = NumberFormatter(); f.locale = .current; f.numberStyle = .decimal; f.usesGroupingSeparator = grouping; f.maximumFractionDigits = 8
        return f.string(from: NSNumber(value: value)) ?? "—"
    }
    struct Reading: Identifiable {
        let id = UUID()
        let value: Double
        let unit: TravelUnit
        let text: String
    }
    static func readings(_ text: String) -> [Reading] {
        var result: [Reading] = []
        for unit in TravelUnit.all where !unit.aliases.isEmpty {
            let aliases = unit.aliases.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
            guard let regex = try? NSRegularExpression(pattern: "(?<![\\w.,])-?\\d+(?:[.,]\\d+)?\\s*(?:" + aliases + ")(?![\\p{L}])", options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range, in: text) else { continue }
                let snippet = String(text[range])
                guard let numberRange = snippet.range(of: #"^-?\d+(?:[.,]\d+)?"#, options: .regularExpression), let value = parse(String(snippet[numberRange])) else { continue }
                result.append(Reading(value: value, unit: unit, text: snippet))
            }
        }
        return result
    }
}
