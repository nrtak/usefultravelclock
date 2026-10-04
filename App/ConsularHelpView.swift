import SwiftUI

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

enum ConsularMapSearch {
    static func url(passportCountry: String, destination: String?) -> URL? {
        guard let country = PassportCountry.named(passportCountry) else { return nil }
        let area = destination?.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = country.englishName + " embassy or consulate near " + ((area?.isEmpty == false) ? area! : "me")
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url
    }
}

struct ConsularHelpCard: View {
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @Environment(\.openURL) private var openURL
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @AppStorage("trip-passport-country") private var passportCountry = ""
    @AppStorage("trip-consular-near-destination") private var nearDestination = true
    @State private var settings = false
    @State private var openFailed = false
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    private var title: String {
        guard let country = PassportCountry.named(passportCountry) else { return "Closest embassy or consulate" }
        return "Closest " + country.name + " embassy or consulate"
    }
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "building.columns").font(.title3).foregroundStyle(.blue).accessibilityHidden(true)
            Button { settings = true } label: {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "pencil").font(.caption2).foregroundStyle(.blue)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain).accessibilityLabel(title + ", choose country and search location")
            Button { openMaps() } label: {
                Label("Map", systemImage: "map").font(.subheadline.weight(.semibold)).frame(minHeight: 32)
            }.buttonStyle(.bordered).accessibilityLabel("Open consular help search in Apple Maps")
        }.padding(10).background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .sheet(isPresented: $settings) {
                ConsularHelpSettings(passportCountry: $passportCountry, nearDestination: $nearDestination, destination: destination)
            }
            .alert("Couldn’t open Maps", isPresented: $openFailed) { Button("OK", role: .cancel) {} } message: {
                Text("Open Apple Maps and search for your country’s embassy or consulate.")
            }
    }
    private func openMaps() {
        guard PassportCountry.named(passportCountry) != nil else { settings = true; return }
        let area = nearDestination ? destination.map { $0.name + ", " + $0.country } : nil
        guard let url = ConsularMapSearch.url(passportCountry: passportCountry, destination: area) else { settings = true; return }
        openURL(url) { accepted in if !accepted { openFailed = true } }
    }
}

private struct ConsularHelpSettings: View {
    @Binding var passportCountry: String
    @Binding var nearDestination: Bool
    let destination: City?
    @Environment(\.dismiss) private var dismiss
    @State private var chooseCountry = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Passport country") {
                    Button { chooseCountry = true } label: {
                        HStack {
                            Text(PassportCountry.named(passportCountry)?.name ?? "Search passport country").foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "magnifyingglass")
                        }.frame(minHeight: 44)
                    }
                    Text("Choose the country whose consular help you need. This can differ from your home location.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Search near") {
                    if let destination {
                        Button { nearDestination = true } label: { option("Destination · " + destination.name, selected: nearDestination) }.buttonStyle(.plain)
                    }
                    Button { nearDestination = false } label: { option("Current location in Maps", selected: !nearDestination || destination == nil) }.buttonStyle(.plain)
                }
                Section {
                    Text("The Map button opens an embassy or consulate search in Apple Maps. Choose the relevant office there for its location, directions and available contact information. Search results are provided by Apple Maps.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Consular Help").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Done") { dismiss() } } }
                .sheet(isPresented: $chooseCountry) {
                    PassportCountryPicker { country in passportCountry = country.id; chooseCountry = false }
                }
        }
    }
    private func option(_ name: String, selected: Bool) -> some View {
        HStack { Text(name); Spacer(); Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.blue : Color.secondary) }
            .frame(minHeight: 44).contentShape(Rectangle())
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
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
                if results.isEmpty { Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Search for your passport country." : "No country found. Try its name or two-letter code.").foregroundStyle(.secondary) }
            }.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Country or code")
                .navigationTitle("Passport country").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } } }
        }
    }
}
