import SwiftUI

struct CityManagementSheet: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var replacing = false
    @State private var duplicate = false
    let city: City
    private var index: Int { store.cityIDs.firstIndex(of: city.id) ?? 0 }
    var body: some View {
        NavigationStack {
            Form {
                Section("Personalize") {
                    TextField("Nickname (for example, Friend)", text: Binding(
                        get: { store.nicknames[city.id] ?? "" },
                        set: { store.nicknames[city.id] = String($0.prefix(40)) }
                    ))
                    Toggle("Pin to top", isOn: Binding(
                        get: { store.favoriteIDs.contains(city.id) },
                        set: { _ in store.toggleFavorite(city.id) }
                    ))
                }
                Button("Set as Home") { store.homeCityID = city.id; store.homeMode = .manual; dismiss() }
                Button("Change city") { replacing = true }
                Button("Move up") { move(-1) }
                Button("Move down") { move(1) }
                Button("Remove city", role: .destructive) { store.toggleCity(city.id); dismiss() }
            }.navigationTitle(city.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }.sheet(isPresented: $replacing) {
            CityPickerSheet(initialID: city.id) { replacement in
                if replacement == city.id { return }
                if store.replaceCity(city.id, with: replacement) { dismiss() }
                else { duplicate = true }
            }
        }
        .alert("City already added", isPresented: $duplicate) { Button("OK", role: .cancel) {} }
    }
    private func move(_ delta: Int) {
        let order = store.orderedCities().map(\.id)
        guard let source = order.firstIndex(of: city.id), order.indices.contains(source + delta) else { return }
        store.moveCity(city.id, to: order[source + delta])
    }
}
