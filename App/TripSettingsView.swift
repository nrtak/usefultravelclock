import SwiftUI
import UIKit
struct TripSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @EnvironmentObject private var appLock: TripAppLock
    @AppStorage("trip-home-color") private var home = "EAF4ED"
    @AppStorage("trip-destination-color") private var destination = "EAF1FC"
    @AppStorage("trip-currency-color") private var currency = "F3F3F3"
    var body: some View {
        NavigationStack {
            List {
                Section("Privacy") {
                    Toggle("Lock app", isOn: Binding(get: { appLock.enabled }, set: { value in Task { await appLock.setEnabled(value) } }))
                        .disabled(appLock.authenticating)
                    Text("Unlock with Face ID, Touch ID or your iPhone passcode (PIN). Uses the security already set up on your iPhone. Locks when you leave the app; widgets are not protected.").font(.caption).foregroundStyle(.secondary)
                    if !appLock.error.isEmpty { Text(appLock.error).font(.caption).foregroundStyle(.secondary) }
                }
                Section("Appearance") {
                    Picker("Theme", selection: $clock.theme) { ForEach(ThemeMode.allCases) { Text($0.rawValue.capitalized).tag($0) } }
                    Text("Box theme").font(.caption).foregroundStyle(.secondary)
                    ForEach(BoxTheme.allCases) { theme in
                        Button {
                            home = theme.colors[0]; destination = theme.colors[1]; currency = theme.colors[2]
                        } label: {
                            HStack {
                                Text(theme.rawValue).foregroundStyle(.primary)
                                Spacer()
                                ForEach(Array(theme.colors.enumerated()), id: \.offset) { _, hex in
                                    RoundedRectangle(cornerRadius: 5).fill(Color(hex: hex)).frame(width: 32, height: 24)
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.4)))
                                }
                                Image(systemName: home == theme.colors[0] && destination == theme.colors[1] && currency == theme.colors[2] ? "checkmark.circle.fill" : "circle").frame(width: 22)
                            }
                        }.accessibilityLabel(theme.rawValue + " box theme")
                    }
                }
                Section("Clock settings") {
                    Toggle("24-hour time", isOn: $clock.use24)
                    Toggle("Analog clocks", isOn: $clock.showAnalog)
                    Toggle("Date", isOn: $clock.showDate)
                    Toggle("Day of the week", isOn: $clock.showWeekday)
                    Toggle("Time difference", isOn: $clock.showDifference)
                    Picker("Home location", selection: $clock.homeMode) {
                        ForEach(HomeMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    if clock.homeMode == .manual {
                        Picker("Home city", selection: $clock.homeCityID) {
                            ForEach(clock.allCities) { Text($0.label).tag($0.id) }
                        }
                    }
                }
                Section("About & support") {
                    NavigationLink { TripHelpView() } label: { Label("Help", systemImage: "questionmark.circle") }
                    NavigationLink { CurrencyInformationView() } label: { Label("Rates & privacy", systemImage: "hand.raised") }
                    NavigationLink { TripCreditsView() } label: { Label("Credits", systemImage: "heart") }
                    NavigationLink { TripAppInformationView() } label: {
                        HStack { Label("App information", systemImage: "info.circle"); Spacer(); Text(TripAppInformation.version).foregroundStyle(.secondary).font(.caption) }
                    }
                }
            }.navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Done") { dismiss() } }.tripToolbarBackground() }
            .onAppear {
                if !BoxTheme.allCases.contains(where: { $0.colors == [home, destination, currency] }) { home = "EAF4ED"; destination = "EAF1FC"; currency = "F3F3F3" }
            }
        }
    }
    private func color(_ value: Binding<String>) -> Binding<Color> { Binding(get: { Color(hex: value.wrappedValue) }, set: { color in var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a); value.wrappedValue = String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255)) }) }
}
extension Color {
    init(hex: String) { let value = UInt32(hex, radix: 16) ?? 0xF3F3F3; self.init(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255) }
    static func readable(on hex: String) -> Color { let n = UInt32(hex, radix:16) ?? 0xFFFFFF; let values = [Double((n >> 16)&255)/255, Double((n >> 8)&255)/255, Double(n&255)/255].map { $0 <= 0.04045 ? $0/12.92 : pow(($0+0.055)/1.055, 2.4) }; return values[0]*0.2126 + values[1]*0.7152 + values[2]*0.0722 > 0.179 ? .black : .white }
}


enum BoxTheme: String, CaseIterable, Identifiable {
    case standard = "Standard", coastal = "Coastal", warm = "Warm", outline = "Outline"
    var id: String { rawValue }
    var colors: [String] {
        switch self {
        case .standard: return ["EAF4ED", "EAF1FC", "F3F3F3"]
        case .coastal: return ["E4F4F2", "E8EDFA", "F3F5F7"]
        case .warm: return ["FFF3DB", "F4EAF7", "F5F2EE"]
        case .outline: return ["FFFFFF", "FFFFFF", "FFFFFF"]
        }
    }
}

private enum TripAppInformation {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unavailable" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unavailable" }
}
private struct TripHelpView: View {
    var body: some View {
        List {
            Section("Home") { Text("Choose your Home and Destination cities. Edit either currency amount to convert both ways. Tap the swap arrows to reverse currencies, or Full converter for more tools.") }
            Section("Conversions") { Text("Currency is the main tool. Add multiple prices supports addition and subtraction; Clear all asks before removing entries. Unit converter handles measurements such as distance, temperature and volume.") }
            Section("Camera & photos") {
                Text("The checkmark shows the selected input. Point the camera at a clear price or measurement, or choose Photo. Use the shutter to keep a reference image. Pause holds recognition; Resume or Scan again starts a new reading.")
                Text("Review detected values and units before saving. For prices, Include unmarked numbers also reads values without a currency label, so quantities and product IDs can be mistaken for prices.")
            }
            Section("Saved entries") { Text("Save a conversion with a note and optional photo. The preview shows what will be saved. Open Saved to revisit it. Swipe a saved conversion to delete; Undo restores the most recent deletion during the current session.") }
            Section("World Time") {
                Text("The comparison slider starts at Now, centered at zero. Move it to compare all cities at another time; Return to now restores live clocks. Yesterday and Tomorrow compare each city's date with Home.")
                Text("Hold Home or Destination to change its city. Hold an additional city to edit or reorder the list, then tap Done.")
            }
            Section("Translate") { Text("Choose source and target languages, then enter text or use Camera or Photo. English (General) has no country specified. Language downloads may be needed. Save a translation with a reference image and note.") }
            Section("My Trip") { Text("Add hotel and transport details. Set departure and arrival locations to display their local times. Entries without a selected location use device time.") }
            Section("Weather & offline use") { Text("Tap Weather for hourly and daily forecasts. Refresh updates the selected city when connected. Saved rates and forecasts show their update time; live refreshes and city search need internet.") }
            Section("Tab order & app lock") { Text("Hold a bottom tab, drag to reorder, and tap Done. The app remembers your tab order and last-used tab. Enable Lock app in Settings to use Face ID, Touch ID or your iPhone passcode. Widgets are not protected by the app lock.") }
            Section("Troubleshooting") {
                Text("If scanning finds nothing, move closer, improve lighting or choose a clearer photo. Check camera permission in iPhone Settings. If a rate or forecast is unavailable, connect and retry Refresh.")
                Text("When reporting a bug, include the app version, build number and steps to reproduce it. Remove personal details from any screenshots.")
            }
        }.navigationTitle("Help").navigationBarTitleDisplayMode(.inline)
    }
}
private struct TripCreditsView: View {
    var body: some View {
        List {
            Section("Development") { LabeledContent("App", value: "Trip Info"); LabeledContent("Developer", value: "Irvine Dynamics") }
            Section("Project foundations") { Text("Clock and currency tools build on UsefulTravelClock and SimpleCurrency. Original contributor and license notices are retained in the source repository.") }
            Section("Services & frameworks") {
                LabeledContent("Reference rates", value: "Frankfurter")
                LabeledContent("Weather", value: "Apple WeatherKit")
                LabeledContent("City search", value: "Apple Maps")
                LabeledContent("Text recognition", value: "Apple Vision & VisionKit")
                LabeledContent("Translation", value: "Apple Translation")
                Text("Weather source links appear beside Apple Weather credits in the weather views.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Credits").navigationBarTitleDisplayMode(.inline)
    }
}
private struct TripAppInformationView: View {
    var body: some View {
        List {
            Section("Installed app") {
                LabeledContent("Name", value: "Trip Info")
                LabeledContent("Version", value: TripAppInformation.version)
                LabeledContent("Build", value: TripAppInformation.build)
                LabeledContent("Developer", value: "Irvine Dynamics")
                Text("© 2026 Irvine Dynamics").font(.caption).foregroundStyle(.secondary)
            }
            Section("Support") {
                Text("Include this version and build number when reporting an issue.")
            }
        }.navigationTitle("App information").navigationBarTitleDisplayMode(.inline)
    }
}
