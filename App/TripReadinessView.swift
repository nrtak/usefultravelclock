import SwiftUI

struct TripReadinessView: View {
    @EnvironmentObject private var trip: TripStore
    @EnvironmentObject private var weather: TripWeatherStore
    @ObservedObject var currency: ConverterStore
    @ObservedObject private var connection = TripConnectionStore.shared
    let cities: [City]
    @State private var readable = Set<UUID>()
    @State private var checking = true
    var body: some View {
        List {
            Section {
                Label(connection.isOffline ? "You are offline" : "You are connected", systemImage: connection.isOffline ? "wifi.slash" : "wifi")
                Text("Check saved information before departure. Weather and rates can become outdated; online booking websites and new location searches require internet.").font(.subheadline)
            }
            Section("Trips & documents") {
                status("Travel details", detail: trip.unlocked ? "\(trip.records.count) saved entries on this iPhone" : "Unlock travel details to check", ready: trip.unlocked && !trip.records.isEmpty)
                if checking { ProgressView("Checking saved documents…") }
                else if trip.documents.isEmpty { Text("No documents saved. Add tickets and confirmations from My Trip.") }
                else {
                    ForEach(trip.documents) { document in
                        status(document.name, detail: readable.contains(document.id) ? "Readable offline" : "Could not read saved copy · import the original again", ready: readable.contains(document.id))
                    }
                }
            }
            Section("Currency") {
                status(currency.source + " → " + currency.target,
                       detail: currency.source == currency.target ? "Same currency · no rates needed" : currency.rateDetail,
                       ready: currency.source == currency.target || (currency.snapshot?.multiplier(from: currency.source, to: currency.target) != nil && !currency.cacheWriteFailed))
                if currency.cacheWriteFailed { Text("The latest rates could not be saved. Retry refresh before leaving.").foregroundStyle(.orange) }
                if currency.usingBundledRates { Text("Included rates are available offline. Refresh while connected for newer rates.").font(.caption) }
                if currency.snapshot?.needsRefresh(from: currency.source, to: currency.target) == true { Label("Saved rates are over a week old or have an unexpected date. Refresh before departure; conversions are estimates.", systemImage: "exclamationmark.triangle").font(.subheadline) }
                Button("Refresh rates") { Task { await currency.refresh(force: true) } }.disabled(connection.isOffline || currency.isLoading)
            }
            Section("Weather") {
                ForEach(cities) { city in
                    if let place = weather.locations[city.id] {
                        status(city.name, detail: weather.status(for: place, offline: connection.isOffline), ready: weather.cache[place.id] != nil && !weather.cacheWriteFailures.contains(place.id))
                        if let saved = weather.cache[place.id] { Text("Last fetched " + saved.fetchedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                    } else { status(city.name, detail: "No saved location or forecast", ready: false) }
                    Button("Refresh " + city.name) { Task { await weather.load(city: city, force: true) } }.disabled(connection.isOffline || weather.loading.contains(city.id))
                }
                if cities.isEmpty { Text("Choose a Home or Destination city to check weather.") }
            }
            Section("Reminders") {
                Text("\(trip.records.filter { $0.reminderMinutes != nil }.count) travel entries have reminders enabled. Delivery also depends on iPhone notification and Focus settings.")
                TripReminderStatus(store: trip.reminders)
            }
        }.navigationTitle("Offline readiness")
        .task(id: trip.unlocked) {
            checking = true
            readable = await trip.readableDocuments()
            checking = false
        }
    }
    private func status(_ title: String, detail: String, ready: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: ready ? "checkmark.circle" : "exclamationmark.triangle").font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine).accessibilityValue(ready ? "Available offline" : "Needs attention")
    }
}
