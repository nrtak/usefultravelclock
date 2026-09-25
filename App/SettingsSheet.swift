//  Useful Travel Clock

import SwiftUI

/// Settings: Appearance (light / dark / system) and Home location
/// (automatic from the device, or a manually picked home city).
struct SettingsSheet: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            Form {
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
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
