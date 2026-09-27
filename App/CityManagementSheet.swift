import SwiftUI

struct CityManagementSheet: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var replacing = false
    @State private var duplicate = false
    @State private var nickname = ""
    @FocusState private var naming: Bool
    let city: City
    private var index: Int { store.cityIDs.firstIndex(of: city.id) ?? 0 }
    var body: some View {
        NavigationStack {
            Form {
                Section("Personalize") {
                    LabeledContent("Location", value: city.label)
                    TextField("Nickname (for example, Friend)", text: $nickname)
                        .focused($naming).onSubmit { saveNickname() }
                    Toggle("Pin to top", isOn: Binding(
                        get: { store.favoriteIDs.contains(city.id) },
                        set: { _ in saveNickname(); store.toggleFavorite(city.id) }
                    ))
                }
                Button("Set as Home") { saveNickname(); store.edit { store.homeCityID = city.id; store.homeMode = .manual }; dismiss() }
                Button("Change city") { saveNickname(); replacing = true }
                Button("Move up") { move(-1) }
                Button("Move down") { move(1) }
                Button("Remove", role: .destructive) { saveNickname(); store.removeCity(city.id); dismiss() }
            }.navigationTitle("Personalize").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Undo") {
                            saveNickname(); store.undoLastEdit()
                            nickname = store.nicknames[city.id] ?? ""
                            if !store.cityIDs.contains(city.id) { dismiss() }
                        }.disabled(!store.canUndo && nickname == (store.nicknames[city.id] ?? ""))
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { saveNickname(); dismiss() } }
                }
        }.sheet(isPresented: $replacing) {
            CityPickerSheet(initialID: city.id) { replacement in
                if replacement == city.id { return }
                if store.replaceCity(city.id, with: replacement) { dismiss() }
                else { duplicate = true }
            }
        }
        .alert("City already added", isPresented: $duplicate) { Button("OK", role: .cancel) {} }
        .onAppear { nickname = store.nicknames[city.id] ?? "" }
        .onChange(of: naming) { focused in if !focused { saveNickname() } }
        .onDisappear { saveNickname() }
    }
    private func saveNickname() {
        guard store.cityIDs.contains(city.id) else { return }
        let name = String(nickname.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if name != (store.nicknames[city.id] ?? "") { store.nicknames[city.id] = name }
    }
    private func move(_ delta: Int) {
        let order = store.orderedCities().map(\.id)
        guard let source = order.firstIndex(of: city.id), order.indices.contains(source + delta) else { return }
        store.moveCity(city.id, to: order[source + delta])
    }
}
