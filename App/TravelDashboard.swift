import SwiftUI

struct TravelDashboard: View {
    @ObservedObject var currency: ConverterStore
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @StateObject private var trip = TripStore()
    @StateObject private var weather = TripWeatherStore()
    @Environment(\.scenePhase) private var phase
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @AppStorage("trip-home-color") private var homeColor = "EAF4ED"
    @AppStorage("trip-destination-color") private var destinationColor = "EAF1FC"
    @AppStorage("trip-currency-color") private var currencyColor = "F3F3F3"
    @State private var tab = 0
    @State private var picker: String?
    @State private var settings = false
    @State private var shift: Double = 0
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { home.navigationTitle("Trip Info").toolbar { Button { settings = true } label: { Image(systemName: "gearshape") } } }.tabItem { Label("Home", systemImage: "house") }.tag(0)
            CurrencyConverterView(store: currency).tabItem { Label("Currency", systemImage: "banknote") }.tag(1)
            NavigationStack { world.navigationTitle("World Time").toolbar { Button("Back") { tab = 0 } } }.tabItem { Label("World Time", systemImage: "clock") }.tag(2)
            NavigationStack { TravelRecordsView().navigationTitle("My Trip").toolbar { Button("Back") { tab = 0 } } }.tabItem { Label("My Trip", systemImage: "suitcase") }.tag(3)
            NavigationStack { TripTranslateView().navigationTitle("Translate").toolbar { Button("Back") { tab = 0 } } }.tabItem { Label("Translate", systemImage: "character.bubble") }.tag(4)
        }
        .overlay { if phase != .active { Color(.systemBackground).ignoresSafeArea().overlay(Label("Trip Info", systemImage: "lock").font(.title)) } }
        .environmentObject(weather)
        .environmentObject(trip)
        .sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) {
            TripCityPicker { city in
                if picker == "home" { clock.homeMode = .manual; clock.homeCityID = city.id } else { destinationID = city.id }
                picker = nil
            }
        }
        .sheet(isPresented: $settings) { TripSettingsView() }
        .alert("Couldn’t complete action", isPresented: Binding(get: { trip.error != nil }, set: { if !$0 { trip.error = nil } })) { Button("OK") { trip.error = nil } } message: { Text(trip.error ?? "") }
        .onChange(of: tab) { _, _ in shift = 0 }
        .onChange(of: phase) { _, value in if value != .active { trip.lock(); shift = 0 } }
        .task { await currency.refresh() }
    }
    private var home: some View {
        ScrollView {
        VStack(spacing: 10) {
            TimelineView(.periodic(from: .now, by: 30)) { context in clocks(at: context.date, selectable: true) }
            VStack(alignment: .leading, spacing: 10) {
                Text("Currency").font(.headline)
                HStack { quick(.source); Image(systemName: "arrow.left.arrow.right"); quick(.target) }
                HStack { Text(currency.detail).font(.caption); Spacer(); Button("Full converter") { tab = 1 } }
            }.padding().foregroundStyle(Color.readable(on: currencyColor)).background(Color(hex: currencyColor), in: RoundedRectangle(cornerRadius: 16))
            TripWeatherCard(home: clock.homeMode == .manual ? clock.homeCity : nil, destination: destination)
            Button { tab = 3 } label: {
                HStack { VStack(alignment: .leading) { Text("My Trip").font(.caption); Text(trip.records.filter { $0.start >= Date() }.sorted { $0.start < $1.start }.first?.name ?? "View travel details").font(.headline) }; Spacer(); Image(systemName: "chevron.right") }.padding()
            }.buttonStyle(.plain).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) { Label("Hotel", systemImage: "bed.double"); Button(trip.unlocked ? "Hide" : "Unlock") { if trip.unlocked { trip.lock() } else { Task { await trip.unlock() } } }; Spacer() }
                if trip.unlocked {
                    if let hotel = trip.records.first(where: { $0.kind == "Hotel" }) { Text(hotel.name).font(.headline); Text(hotel.from).font(.subheadline).textSelection(.enabled); Text("\(hotel.start.formatted(date: .abbreviated, time: .omitted)) – \(hotel.end.formatted(date: .abbreviated, time: .omitted))").font(.caption) }
                    else { Text("Add your hotel in My Trip.").font(.caption) }
                }
            }.padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 0)
        }.padding(12)
        }.scrollBounceBehavior(.basedOnSize).navigationBarTitleDisplayMode(.inline)
    }
    private func quick(_ side: AmountSide) -> some View {
        let code = side == .source ? currency.source : currency.target
        return VStack(alignment: .leading) { Text(code).font(.caption); HStack(spacing: 4) { Text(Currency.named(code).symbol); TextField("Amount", text: Binding(get: { currency.fieldText(for: side, focused: false) }, set: { currency.edit($0.replacingOccurrences(of: Locale.current.groupingSeparator ?? ",", with: ""), side: side) })).keyboardType(.decimalPad).font(.title2).monospacedDigit() } }
    }
    private var world: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let date = context.date.addingTimeInterval(shift * 3600)
            VStack(spacing: 12) {
                Text(shift == 0 ? "Live time" : "Preview — all times shifted").font(.headline)
                clocks(at: date, selectable: false)
                ForEach(Array(clock.selectedCities.filter { $0.id != destinationID && $0.id != clock.homeCityID }.prefix(3))) { city in
                    HStack { VStack(alignment: .leading) { Text(city.name).font(.headline); Text(city.country).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(time(date, zone: city.timeZoneID)).font(.title3).monospacedDigit() }.padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                VStack { HStack { Text("Compare all cities"); Spacer(); Button("Return to now") { shift = 0 }.disabled(shift == 0) }; Slider(value: $shift, in: -12...24, step: 0.5); Text(shift == 0 ? "Live time" : "Preview: \(shift.formatted()) hours from now").font(.caption) }.padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 0)
            }.padding()
        }.navigationBarTitleDisplayMode(.inline)
    }
    private func clocks(at date: Date, selectable: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            clockBox(role: "Home", name: clock.homeMode == .manual ? clock.homeCity?.name ?? "Home" : "Device time", zone: clock.homeTimeZoneID, date: date, color: .green, selectable: selectable)
            clockBox(role: "Destination", name: destination?.name ?? "Choose city", zone: destination?.timeZoneID ?? "UTC", date: date, color: .blue, selectable: selectable)
        }
    }
    private func clockBox(role: String, name: String, zone: String, date: Date, color: Color, selectable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(role).font(.caption)
            Button { picker = role == "Home" ? "home" : "destination" } label: { HStack { Text(name).font(.headline).lineLimit(1).minimumScaleFactor(0.75); if selectable { Image(systemName: "pencil").font(.caption) } } }.buttonStyle(.plain).disabled(!selectable)
            Text(time(date, zone: zone)).font(.title2.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(TimeEngine.compactDate(date, timeZoneID: zone)).font(.caption)
            Text(role == "Destination" ? difference(zone: zone, date: date) : "Home time").font(.caption2).lineLimit(2).frame(height: 28, alignment: .topLeading)
        }.foregroundStyle(Color.readable(on: role == "Home" ? homeColor : destinationColor)).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(hex: role == "Home" ? homeColor : destinationColor), in: RoundedRectangle(cornerRadius: 14))
    }
    private func time(_ date: Date, zone: String) -> String { let f = DateFormatter(); f.timeZone = TimeZone(identifier: zone); f.dateFormat = clock.use24 ? "HH:mm" : "h:mm a"; return f.string(from: date) }
    private func difference(zone: String, date: Date) -> String { let n = ((TimeZone(identifier: zone)?.secondsFromGMT(for: date) ?? 0) - (TimeZone(identifier: clock.homeTimeZoneID)?.secondsFromGMT(for: date) ?? 0)) / 60; return n == 0 ? "Same time as Home" : "\(abs(n)/60)h\(abs(n)%60 == 0 ? "" : " \(abs(n)%60)m") \(n > 0 ? "ahead of" : "behind") Home" }
}
struct TripCityPicker: View {
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @State private var query = ""
    let select: (City) -> Void
    var body: some View { NavigationStack { List { if query.isEmpty { Text("Search for a city") } else { ForEach(CitySearch.search(query, in: clock.allCities)) { city in Button(city.label) { select(city) } } } }.searchable(text: $query).navigationTitle("Choose city") } }
}
