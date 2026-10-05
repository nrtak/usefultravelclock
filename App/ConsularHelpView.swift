import SwiftUI
import MapKit
import CoreLocation

struct PassportCountry: Identifiable {
    let id: String
    var name: String { Locale.current.localizedString(forRegionCode: id) ?? id }
    var englishName: String { Locale(identifier: "en").localizedString(forRegionCode: id) ?? id }
    static let all = Locale.Region.isoRegions.map { $0.identifier }
        .filter { $0.count == 2 && $0.allSatisfy { $0.isASCII && $0.isLetter } }
        .map { PassportCountry(id: $0) }
    static func named(_ code: String) -> PassportCountry? { all.first { $0.id == code } }
    func matches(_ query: String) -> Bool {
        let nativeName = Locale(identifier: id).localizedString(forRegionCode: id) ?? id
        return [id, name, englishName, nativeName].contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}


@MainActor
final class ConsularLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?
    private var timeout: Task<Void, Never>?
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyKilometer }
    func request(_ completion: @escaping (CLLocation?) -> Void) {
        finish(nil)
        self.completion = completion
        timeout = Task { try? await Task.sleep(nanoseconds: 12_000_000_000); if !Task.isCancelled { finish(nil) } }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: finish(nil)
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { finish(locations.last) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }
    func cancel() { completion = nil; timeout?.cancel(); manager.stopUpdatingLocation() }
    private func finish(_ location: CLLocation?) {
        let callback = completion; completion = nil; timeout?.cancel(); timeout = nil
        manager.stopUpdatingLocation(); callback?(location)
    }
}

enum ConsularResults {
    static func nearest(_ items: [MKMapItem], to origin: CLLocation) -> MKMapItem? {
        items.filter { item in
            (item.name ?? "").range(of: "embass|consul|大使館|領事館|ambassad|botschaft|konsulat|embajad|embaixad|대사관|영사관|使馆|使館|领事|領事|سفارة|قنصل", options: [.regularExpression, .caseInsensitive]) != nil
        }.min { ($0.placemark.location?.distance(from: origin) ?? .greatestFiniteMagnitude) <
                ($1.placemark.location?.distance(from: origin) ?? .greatestFiniteMagnitude) }
    }
    static func address(_ item: MKMapItem) -> String {
        let p = item.placemark
        return [p.subThoroughfare, p.thoroughfare, p.locality, p.administrativeArea, p.postalCode, p.country]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct ConsularHelpCard: View {
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @AppStorage("trip-passport-country") private var countryCode = ""
    @StateObject private var location = ConsularLocation()
    @State private var choosingCountry = false
    @State private var result: MKMapItem?
    @State private var busy = false
    @State private var message = ""
    @State private var generation = UUID()
    private var country: PassportCountry? { PassportCountry.named(countryCode) }
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "building.columns").foregroundStyle(.teal)
                Button { choosingCountry = true } label: {
                    HStack(spacing: 6) {
                        Text(country.map { "Closest " + $0.name + " embassy or consulate" } ?? "Closest embassy or consulate")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.primary)
                        Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.blue)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.buttonStyle(.plain)
                if busy { ProgressView() }
                else {
                    Button { find() } label: {
                        if result == nil { Text("Find").font(.caption.weight(.semibold)) }
                        else { Image(systemName: "arrow.clockwise") }
                    }.frame(minWidth: 44, minHeight: 44).disabled(country == nil)
                        .accessibilityLabel("Find closest embassy or consulate")
                }
            }
            if let result {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name ?? "Embassy or consulate").font(.caption.weight(.semibold)).foregroundStyle(Color.primary)
                        Text(ConsularResults.address(result)).font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    }
                    Spacer(minLength: 0)
                    Button("Open in Maps") { result.openInMaps() }.font(.caption).frame(minHeight: 44)
                }
            } else if !message.isEmpty {
                Text(message).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(country == nil ? "Choose the country whose consular help you need." : "Find near you, or your destination.").font(.caption2).foregroundStyle(.secondary)
            }
            if result != nil { Text(message + " · Apple Maps results. Verify details before visiting.").font(.caption2).foregroundStyle(.secondary) }
        }.padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.15)))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .sheet(isPresented: $choosingCountry) {
                PassportCountryPicker { selected in countryCode = selected.id; choosingCountry = false; find() }
            }
            .onChange(of: destinationID) { _, _ in reset() }
            .onDisappear { generation = UUID(); busy = false; location.cancel() }
    }
    private func reset() { generation = UUID(); location.cancel(); busy = false; result = nil; message = "" }
    private func find() {
        guard let country else { choosingCountry = true; return }
        reset(); busy = true
        let token = generation
        let fallback = destination
        location.request { current in
            Task { @MainActor in
                do {
                    var origin = current
                    var area = "Near you"
                    if origin == nil {
                        guard let fallback else { throw ConsularError.noLocation }
                        let request = MKLocalSearch.Request()
                        request.naturalLanguageQuery = fallback.name + ", " + fallback.country
                        let response = try await MKLocalSearch(request: request).start()
                        origin = response.mapItems.first?.placemark.location
                        area = "Near " + fallback.name
                    }
                    guard let origin else { throw ConsularError.noLocation }
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = country.englishName + " embassy or consulate"
                    request.region = MKCoordinateRegion(center: origin.coordinate, latitudinalMeters: 300_000, longitudinalMeters: 300_000)
                    let response = try await MKLocalSearch(request: request).start()
                    guard token == generation else { return }
                    result = ConsularResults.nearest(response.mapItems, to: origin)
                    message = result == nil ? "No matching office found. Try another country or destination." : area
                } catch {
                    guard token == generation else { return }
                    message = "Couldn’t find an office. Check internet and your destination, then retry."
                }
                if token == generation { busy = false }
            }
        }
    }
    private enum ConsularError: Error { case noLocation }
}

private struct PassportCountryPicker: View {
    let select: (PassportCountry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var results: [PassportCountry] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? [] : PassportCountry.all.filter { $0.matches(term) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { country in Button(country.name) { select(country) }.frame(minHeight: 44) }
                if results.isEmpty { Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Search for your country." : "No country found. Try its name or two-letter code.").foregroundStyle(.secondary) }
            }.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Country or code")
                .navigationTitle("Consular country").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } }.tripToolbarBackground() }
        }
    }
}
