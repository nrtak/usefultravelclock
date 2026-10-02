import SwiftUI
import UIKit
struct TripSettingsView: View {
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @AppStorage("trip-home-color") private var home = "EAF4ED"
    @AppStorage("trip-destination-color") private var destination = "EAF1FC"
    @AppStorage("trip-currency-color") private var currency = "F3F3F3"
    var body: some View {
        NavigationStack {
            List {
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
                Section("Utilities") { NavigationLink("Unit Converter") { TripUnitsView() } }
                Section("About & support") {
                    NavigationLink("Help") { Text("Choose home and destination on Home. Currency supports both directions, saved notes and photos, totals, and photo price recognition. Travel details unlock using device authentication.").padding() }
                    NavigationLink("Privacy") { Text("Travel records are encrypted on device. Photos and translations stay locally. Exchange rate requests go to Frankfurter. Weather requests go to Apple WeatherKit; city search uses Apple Maps. Apple’s translation framework may collect API usage metrics; translated content is not included. No app analytics are added.").padding() }
                    NavigationLink("Credits") { Text("Built from SimpleCurrency and UsefulTravelClock. Rates: Frankfurter. Text recognition and translation: Apple.").padding() }
                    Text("Trip Info · Version 1.1")
                    Text("© 2026 Irvine Dynamics").font(.caption)
                }
            }.navigationTitle("Settings").onAppear {
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
