
import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            Form {
                Section("Organize cities") {
                    Picker("Sort cities", selection: $store.sortOrder) {
                        ForEach(CitySort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Button("Edit cities") { store.isEditingCities = true; dismiss() }
                    Text("You can also touch and hold a city in Clocks. Pinned cities always stay at the top.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Display") {
                    Toggle("24-hour time", isOn: $store.use24)
                    Toggle("Analog clocks", isOn: $store.showAnalog)
                    Toggle("Date", isOn: $store.showDate)
                    Toggle("Day of the week", isOn: $store.showWeekday)
                    Toggle("Time difference", isOn: $store.showDifference)
                }
                Section("Appearance") {
                    Picker("Appearance", selection: $store.theme) {
                        ForEach(ThemeMode.allCases) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Home location", selection: $store.homeMode) {
                        ForEach(HomeMode.allCases) { mode in
                            Text(mode.rawValue.capitalized).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch store.homeMode {
                    case .automatic:
                        LabeledContent("This device") {
                            Text(TimeEngine.readableZone(store.deviceTimeZoneID))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .manual:
                        Picker("Home city", selection: $store.homeCityID) {
                            ForEach(store.allCities) { city in
                                Text(city.label).tag(city.id)
                            }
                        }
                    }
                } header: {
                    Text("Home location")
                } footer: {
                    Text("Time differences in the clock list are compared with home.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Undo") { store.undoLastEdit() }.disabled(!store.canUndo)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
