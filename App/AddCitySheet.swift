// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

//  Useful Travel Clock

import SwiftUI

/// Add-city sheet: popular cities up front, typeable search (city, country,
/// region, time zone or airport code), max 10 selected — mirrors the web app.
struct AddCitySheet: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(results) { city in
                        row(for: city)
                    }
                } header: {
                    Text(query.isEmpty ? "Popular cities" : "\(results.count) \(results.count == 1 ? "match" : "matches")")
                } footer: {
                    if results.isEmpty {
                        Text("No cities found. Try a nearby big city or an airport code like LAX.")
                    }
                }
            }
            .searchable(text: $query, prompt: "Search city, country or airport code")
            .navigationTitle("Add a city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }

    private var results: [City] {
        CitySearch.search(query, in: store.allCities)
    }

    private func row(for city: City) -> some View {
        let selected = store.cityIDs.contains(city.id)
        let disabled = !selected && store.cityIDs.count >= UsefulTravelClockStore.maxCities

        return Button {
            store.toggleCity(city.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Design.foreground(scheme))
                    Text(city.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Design.mutedForeground(scheme))
                }
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
            .opacity(disabled ? 0.4 : 1)
        }
        .disabled(disabled)
    }
}
