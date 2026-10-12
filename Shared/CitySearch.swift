
import Foundation

enum CitySearch {

    private static let usStates: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho",
        "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
        "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
        "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
        "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
        "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
        "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
        "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
        "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
        "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
        "WI": "Wisconsin", "WY": "Wyoming", "DC": "District of Columbia"
    ]

    private static func normalize(_ value: String) -> String {
        value.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    static func search(_ query: String, in allCities: [City]) -> [City] {
        let q = normalize(query)
        guard !q.isEmpty else {
            return popularCities(in: allCities)
        }

        var scored: [(city: City, score: Int)] = []
        for city in allCities {
            let name = normalize(city.name)
            let codes = (city.codes ?? []).map { $0.lowercased() }
            let aliases = (city.aliases ?? []).map(normalize)
            let state = city.country == "USA" ? normalize(usStates[(city.region ?? "").uppercased()] ?? "") : ""
            let haystack = [
                name,
                state,
                normalize(city.region ?? ""),
                normalize(city.country),
                normalize(city.timeZoneID.replacingOccurrences(of: "_", with: " ")),
            ] + aliases

            var score = -1
            if !state.isEmpty && (state == q || normalize(city.region ?? "") == q) {
                score = 0
            } else if name.hasPrefix(q) || aliases.contains(where: { $0.hasPrefix(q) }) {
                score = 1
            } else if haystack.contains(where: { $0.contains(q) }) {
                score = 2
            } else if codes.contains(q) {
                score = 3
            } else if codes.contains(where: { $0.hasPrefix(q) }) {
                score = 4
            }

            if score >= 0 { scored.append((city, score)) }
        }

        return scored
            .sorted { a, b in
                a.score != b.score ? a.score < b.score : a.city.name.localizedCompare(b.city.name) == .orderedAscending
            }
            .map { $0.city }
    }

    static func popularCities(in allCities: [City]) -> [City] {
        popularCityIDs.compactMap { id in allCities.first { $0.id == id } }
    }

    static func city(withID id: String, in allCities: [City]) -> City? {
        allCities.first { $0.id == id }
    }
}
