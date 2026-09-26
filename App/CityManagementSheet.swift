import SwiftUI

struct CityManagementSheet: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var replacing = false
    let city: City
    private var index: Int { store.cityIDs.firstIndex(of: city.id) ?? 0 }
    var body: some View {
        NavigationStack {
            Form {
                Button("Set as Home") { store.homeCityID = city.id; store.homeMode = .manual; dismiss() }
                Button("Change city") { replacing = true }
                Button("Move up") { move(-1) }.disabled(index == 0)
                Button("Move down") { move(1) }.disabled(index >= store.cityIDs.count - 1)
                Button("Remove city", role: .destructive) { store.toggleCity(city.id); dismiss() }
            }.navigationTitle(city.name).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }.sheet(isPresented: $replacing) {
            CityPickerSheet(initialID: city.id) { replacement in
                guard !store.cityIDs.contains(replacement), let index = store.cityIDs.firstIndex(of: city.id) else { return }
                store.cityIDs[index] = replacement
                if store.homeCityID == city.id { store.homeCityID = replacement }
                dismiss()
            }
        }
    }
    private func move(_ delta: Int) {
        let destination = index + delta
        guard store.cityIDs.indices.contains(destination) else { return }
        store.cityIDs.swapAt(index, destination)
    }
}
