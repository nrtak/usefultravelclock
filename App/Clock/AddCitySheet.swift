
import SwiftUI

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
            .safeAreaInset(edge: .top, spacing: 0) { CitySearchField(query: $query) }
            .navigationTitle("Add a city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Undo") { store.undoLastEdit() }.disabled(!store.canUndo)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
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

struct CitySearchField: View {
    @Binding var query: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search locations").font(.headline)
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.title3).foregroundStyle(.blue)
                TextField("City, US state, country or airport", text: $query)
                    .font(.body).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityLabel("Search city, US state, country or airport code")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14).frame(minHeight: 56)
            .background(Design.secondary(scheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.6), lineWidth: 1.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Design.background(scheme))
    }
}
