// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

//  Useful Travel Clock

import Foundation

/// Mirrors `searchCities` in the web app: city names rank first,
/// airport codes are a convenience extra.
enum CitySearch {

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
            let haystack = [
                name,
                normalize(city.region ?? ""),
                normalize(city.country),
                normalize(city.timeZoneID.replacingOccurrences(of: "_", with: " ")),
            ] + aliases

            var score = -1
            if name.hasPrefix(q) || aliases.contains(where: { $0.hasPrefix(q) }) {
                score = 0
            } else if haystack.contains(where: { $0.contains(q) }) {
                score = 1
            } else if codes.contains(q) {
                score = 2
            } else if codes.contains(where: { $0.hasPrefix(q) }) {
                score = 3
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
