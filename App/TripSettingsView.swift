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
                    Text("Box colors").font(.caption).foregroundStyle(.secondary)
                    ColorPicker("Home", selection: color($home)); ColorPicker("Destination", selection: color($destination)); ColorPicker("Currency", selection: color($currency)); Button("Restore standard colors") { home = "EAF4ED"; destination = "EAF1FC"; currency = "F3F3F3" } }
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
                Section("Utilities") { NavigationLink("Units") { TripUnitsView() } }
                Section("About & support") {
                    NavigationLink("Help") { Text("Choose home and destination on Home. Currency supports both directions, saved notes and photos, totals, and photo price recognition. Travel details unlock using device authentication.").padding() }
                    NavigationLink("Privacy") { Text("Travel records are encrypted on device. Photos and translations stay locally. Exchange rate requests go to Frankfurter. Weather requests go to Apple WeatherKit; city search uses Apple Maps. Apple’s translation framework may collect API usage metrics; translated content is not included. No app analytics are added.").padding() }
                    NavigationLink("Credits") { Text("Built from SimpleCurrency and UsefulTravelClock. Rates: Frankfurter. Text recognition and translation: Apple.").padding() }
                    Text("Trip Info · Version 1.1")
                    Text("© 2026 Irvine Dynamics").font(.caption)
                }
            }.navigationTitle("Settings")
        }
    }
    private func color(_ value: Binding<String>) -> Binding<Color> { Binding(get: { Color(hex: value.wrappedValue) }, set: { color in var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a); value.wrappedValue = String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255)) }) }
}
extension Color {
    init(hex: String) { let value = UInt32(hex, radix: 16) ?? 0xF3F3F3; self.init(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255) }
    static func readable(on hex: String) -> Color { let n = UInt32(hex, radix:16) ?? 0xFFFFFF; let values = [Double((n >> 16)&255)/255, Double((n >> 8)&255)/255, Double(n&255)/255].map { $0 <= 0.04045 ? $0/12.92 : pow(($0+0.055)/1.055, 2.4) }; return values[0]*0.2126 + values[1]*0.7152 + values[2]*0.0722 > 0.179 ? .black : .white }
}

struct TripUnitsView: View {
    @State private var kind = "Temperature"
    @State private var amount = "20"
    private var result: String { guard let n = Double(amount) else { return "Enter a number" }; switch kind { case "Temperature": return "\((n*9/5+32).formatted()) °F"; case "Distance": return "\((n*0.621371).formatted()) mi"; default: return "\((n*2.20462262).formatted()) lb" } }
    var body: some View { VStack(spacing: 20) { Picker("Unit", selection: $kind) { ForEach(["Temperature", "Distance", "Weight"], id: \.self) { Text($0).tag($0) } }; TextField(kind == "Temperature" ? "Celsius" : kind == "Distance" ? "Kilometers" : "Kilograms", text: $amount).keyboardType(.numbersAndPunctuation).textFieldStyle(.roundedBorder); Text(result).font(.largeTitle); Spacer() }.padding().navigationTitle("Units") }
}
