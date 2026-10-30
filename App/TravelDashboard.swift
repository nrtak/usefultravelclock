import SwiftUI

struct TravelDashboard: View {
    @ObservedObject var currency: ConverterStore
    @EnvironmentObject private var documentInbox: TripDocumentInbox
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @StateObject private var trip = TripStore()
    @StateObject private var weather = TripWeatherStore()
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @AppStorage("trip-home-color") private var homeColor = "EAF4ED"
    @AppStorage("trip-destination-color") private var destinationColor = "EAF1FC"
    @AppStorage("trip-navigation-tab-v2") private var tab = 0
    @AppStorage("trip-home-sections") private var savedHomeSections = HomeSection.defaults
    @State private var editingCities = false
    @State private var cityEditFeedback = 0
    @State private var customizingHome = false
    @State private var homeCapacity = 0
    @State private var tool: DashboardTool?
    @State private var homeRecord: TravelRecord?
    @State private var picker: String?
    @State private var settings = false
    @State private var shift: Double = 0
    @State private var homeDocument: TripPreviewFile?
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                home.navigationTitle("Trip Info").toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Customize") { customizingHome = true }
                            .tripToolbarButtonStyle().accessibilityLabel("Customize Home")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { settings = true } label: { Image(systemName: "gearshape") }
                            .tripToolbarButtonStyle().accessibilityLabel("Settings")
                    }
                }
            }.tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack {
                TravelRecordsView(currency: currency, cities: readinessCities, acceptsIncomingDocuments: tab == 1 && !hasModal).navigationTitle("My Trip")
            }.tabItem { Label("My Trip", systemImage: "suitcase") }.tag(1)
            NavigationStack { tools.navigationTitle("Tools") }
                .tabItem { Label("Tools", systemImage: "square.grid.2x2") }.tag(2)
        }
        .tripNavigationAppearance()
        .tint(.blue)
        .overlay { if phase != .active { Color(.systemBackground).ignoresSafeArea().overlay(Label("Trip Info", systemImage: "lock").font(.title)) } }
        .sheet(isPresented: Binding(get: { picker != nil && tool == nil }, set: { if !$0 { picker = nil } }), onDismiss: routeInbox) { cityPicker }
        .sheet(isPresented: $customizingHome, onDismiss: routeInbox) { HomeCustomizationView(savedSections: $savedHomeSections, capacity: homeCapacity) }
        .sheet(item: $tool, onDismiss: routeInbox) { selection in toolScreen(selection) }
        .sheet(item: $homeRecord, onDismiss: routeInbox) { RecordEditor(record: $0) }
        .sheet(isPresented: $settings, onDismiss: routeInbox) { TripSettingsView() }
        .sheet(item: $homeDocument, onDismiss: { trip.clearDocumentPreviews(); routeInbox() }) { file in TripDocumentPreviewSheet(url: file.url) }
        .alert("Couldn’t complete action", isPresented: Binding(get: { trip.error != nil }, set: { if !$0 { trip.error = nil } })) { Button("OK") { trip.error = nil } } message: { Text(trip.error ?? "") }
        .onChange(of: documentInbox.url) { _, _ in routeInbox() }
        .onAppear { if !(0...2).contains(tab) { tab = 0 }; routeInbox() }
        .onChange(of: tab) { _, _ in shift = 0; editingCities = false }
        .onChange(of: tool) { _, value in if value == nil { shift = 0; editingCities = false; picker = nil } }
        .onChange(of: phase) { _, value in
            if value == .background { homeDocument = nil; trip.lock(); homeRecord = nil; picker = nil; shift = 0; editingCities = false }
            if value == .active { Task { await trip.unlock(); if trip.unlocked { await trip.reminders.synchronize(records: trip.records) }; routeInbox() } }
        }
        .task { await trip.unlock(); await currency.refresh() }
        // Wrap the sheet presenters too: their content needs the same stores as the tabs.
        .environmentObject(weather)
        .environmentObject(trip)
    }

    private var hasModal: Bool { tool != nil || homeRecord != nil || homeDocument != nil || picker != nil || settings || customizingHome }
    private func routeInbox() {
        guard phase == .active, documentInbox.url != nil, !hasModal else { return }
        tab = 1
    }
    private var cityPicker: some View {
        TripCityPicker { city in
            if picker == "home" { clock.homeMode = .manual; clock.homeCityID = city.id }
            else if let selection = picker, selection.hasPrefix("city:") {
                let previous = String(selection.dropFirst(5))
                if city.id != previous && !clock.replaceCity(previous, with: city.id) {
                    trip.error = "That city is already in your world clocks. Choose another city."
                }
            } else { destinationID = city.id }
            picker = nil
        }
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    private var home: some View {
        DashboardHome(currency: currency, savedSections: $savedHomeSections, capacity: $homeCapacity, active: tab == 0 && tool == nil,
            open: openHomeSection, chooseCity: { picker = $0 },
            openRecord: { homeRecord = $0 }, openDocument: { document in
                do { homeDocument = TripPreviewFile(url: try trip.previewURL(document)) }
                catch { trip.error = error.localizedDescription }
            })
    }
    private func openHomeSection(_ section: HomeSection) {
        switch section {
        case .clocks: tool = .world
        case .currency: tool = .currency
        case .trip: tab = 1
        case .weather: tool = .weather
        case .documents: tool = .documents
        case .readiness: tool = .readiness
        }
    }
    private var tools: some View {
        List {
            Section("Travel tools") {
                toolButton(.currency, title: "Currency", detail: "Amounts, multiple prices and saved conversions", symbol: "banknote")
                toolButton(.translate, title: "Translate", detail: "Text, camera and photos", symbol: "character.bubble")
                toolButton(.world, title: "World Time", detail: "Cities and time comparison", symbol: "clock")
                toolButton(.units, title: "Measurements", detail: "Distance, temperature, volume and weight", symbol: "ruler")
                toolButton(.weather, title: "Weather", detail: "Search cities and view forecasts", symbol: "cloud.sun")
            }
        }.navigationBarTitleDisplayMode(.inline)
    }
    private func toolButton(_ selection: DashboardTool, title: String, detail: String, symbol: String) -> some View {
        Button { tool = selection } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(.blue).frame(width: 28)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }.foregroundStyle(.primary).padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
    @ViewBuilder
    private func toolScreen(_ selection: DashboardTool) -> some View {
        if selection == .currency {
            CurrencyConverterView(store: currency, onBack: { tool = nil })
        } else {
            NavigationStack {
                Group {
                    switch selection {
                    case .world:
                        world.navigationTitle("World Time")
                            .sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) { cityPicker }
                    case .translate: TripTranslateView(onClose: { tool = nil }).navigationTitle("Translate")
                    case .units: TripUnitsView()
                    case .weather: TripWeatherSearchView(home: clock.homeMode == .manual ? clock.homeCity : nil, destination: destination)
                    case .documents: TripDocumentsView()
                    case .readiness: TripReadinessView(currency: currency, cities: readinessCities)
                    case .currency: EmptyView()
                    }
                }.toolbar { if selection != .translate { ToolbarItem(placement: .confirmationAction) { Button("Done") { tool = nil } } } }
            }
        }
    }
    private var readinessCities: [City] {
        var seen = Set<String>()
        return [clock.homeMode == .manual ? clock.homeCity : nil, destination].compactMap { $0 }.filter { seen.insert($0.id).inserted }
    }
    private var world: some View {
        TripVisibleTimeline(interval: 30, enabled: tool == .world) { context in
            let date = context.date.addingTimeInterval(shift * 3600)
            ScrollView {
            VStack(spacing: 10) {
                if shift != 0 { Text("Comparing times").font(.headline) }
                HStack {
                    Text(editingCities ? "Drag cities to reorder · Tap pencil to change" : "Hold a city to edit or reorder")
                        .font(.caption2).foregroundStyle(.secondary)
                    if editingCities {
                        Spacer()
                        Button("Done") { editingCities = false }.font(.caption).frame(minHeight: 44)
                    }
                }
                clocks(at: date, selectable: false)
                ForEach(Array(clock.selectedCities.filter { $0.id != destinationID && $0.id != clock.homeCityID }.prefix(3))) { city in
                    reorderableCity(city, at: date)
                }
                VStack { HStack { Text("Compare city times"); Spacer(); Button("Return to now") { shift = 0 }.disabled(shift == 0) }; Slider(value: $shift, in: -24...24, step: 0.5)
                    .overlay(alignment: .bottom) {
                        Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 2, height: 7)
                            .offset(y: 4).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    .accessibilityLabel("Compare city times")
                    .accessibilityValue(shift == 0 ? "Now, zero hours" : "\(shift.formatted()) hours from now"); Text(shift == 0 ? "Now · 0 hours" : "\(shift > 0 ? "+" : "")\(shift.formatted()) hours from now").font(.caption).monospacedDigit() }.padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                if !typeSize.isAccessibilitySize && !editingCities { TripArtwork(symbol: "globe") }
            Spacer(minLength: 0)
            }.padding(12)
            }.scrollBounceBehavior(.basedOnSize)
        }.navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func reorderableCity(_ city: City, at date: Date) -> some View {
        if editingCities {
            comparisonCityRow(city, at: date)
                .draggable(city.id)
                .dropDestination(for: String.self) { items, _ in
                    guard let moved = items.first, moved != city.id,
                          let from = clock.cityIDs.firstIndex(of: moved),
                          let to = clock.cityIDs.firstIndex(of: city.id),
                          moved != destinationID, moved != clock.homeCityID else { return false }
                    var order = clock.cityIDs
                    order.remove(at: from)
                    order.insert(moved, at: to)
                    withAnimation { clock.edit { clock.cityIDs = order; clock.sortOrder = .custom } }
                    return true
                }
                .accessibilityActions {
                    Button("Move up") { moveComparisonCity(city.id, by: -1) }
                    Button("Move down") { moveComparisonCity(city.id, by: 1) }
                    Button("Change city") { picker = "city:" + city.id }
                }
        } else {
            comparisonCityRow(city, at: date)
                .onLongPressGesture(minimumDuration: 0.6) {
                    editingCities = true
                    cityEditFeedback += 1
                }
                .accessibilityAction(named: "Reorder cities") { editingCities = true }
                .accessibilityAction(named: "Change city") { picker = "city:" + city.id }
        }
    }
    private func comparisonCityRow(_ city: City, at date: Date) -> some View {
        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
            if editingCities {
                Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                Button { picker = "city:" + city.id } label: {
                    Image(systemName: "pencil").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Change " + city.name)
            }
            VStack(alignment: .leading) {
                Text(city.name).font(.headline).lineLimit(typeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.7)
                Text(city.country).font(.caption).lineLimit(1).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(time(date, zone: city.timeZoneID)).font(.title3).monospacedDigit()
                if let day = comparisonDay(date, zone: city.timeZoneID) {
                    Text(day).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(editingCities && !reduceMotion ? 0.5 : 0))
            .animation(editingCities && !reduceMotion ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : .default, value: editingCities)
            .sensoryFeedback(.impact(weight: .light), trigger: cityEditFeedback)
            .accessibilityElement(children: editingCities ? .contain : .combine)
            .accessibilityHint(editingCities ? "Use Move up or Move down actions to reorder" : "Use Reorder cities or Change city actions")
    }
    private func moveComparisonCity(_ id: String, by offset: Int) {
        let cities = Array(clock.selectedCities.filter { $0.id != destinationID && $0.id != clock.homeCityID }.prefix(3))
        guard let index = cities.firstIndex(where: { $0.id == id }), cities.indices.contains(index + offset),
              let from = clock.cityIDs.firstIndex(of: id),
              let to = clock.cityIDs.firstIndex(of: cities[index + offset].id) else { return }
        var order = clock.cityIDs
        order.swapAt(from, to)
        clock.edit { clock.cityIDs = order; clock.sortOrder = .custom }
    }
    private func clocks(at date: Date, selectable: Bool, compact: Bool = false) -> some View {
        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))) {
            clockBox(role: "Home", name: clock.homeMode == .manual ? clock.homeCity?.name ?? "Home" : "Device time", zone: clock.homeTimeZoneID, date: date, color: .green, selectable: selectable, compact: compact)
            clockBox(role: "Destination", name: destination?.name ?? "Choose city", zone: destination?.timeZoneID ?? "UTC", date: date, color: .blue, selectable: selectable, compact: compact)
        }
    }
    private func clockBox(role: String, name: String, zone: String, date: Date, color: Color, selectable: Bool, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(role).font(.caption).frame(maxWidth: .infinity)
            if selectable {
                Button { picker = role == "Home" ? "home" : "destination" } label: {
                    HStack { Text(name).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75); Image(systemName: "pencil").font(.caption) }
                }.frame(maxWidth: .infinity).buttonStyle(.plain)
            } else {
                Text(name).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: .infinity)
            }
            Text(time(date, zone: zone)).frame(maxWidth: .infinity).font(.title2.weight(.semibold)).monospacedDigit().minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.7).lineLimit(1)
                .accessibilityLabel(role + " time " + time(date, zone: zone))
            if compact {
                HStack(spacing: 6) {
                    if clock.showAnalog { TripAnalogClock(date: date, zone: zone) }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(TimeEngine.compactDate(date, timeZoneID: zone)).font(.caption).lineLimit(1).minimumScaleFactor(0.75)
                        if role == "Destination" { Text(difference(zone: zone, date: date)).font(.caption2).lineLimit(1) }
                    }
                }.frame(maxWidth: .infinity)
            } else {
                if clock.showAnalog { TripAnalogClock(date: date, zone: zone).frame(maxWidth: .infinity) }
                Text(comparisonDate(date, zone: zone)).font(.caption).frame(maxWidth: .infinity)
                Text(role == "Destination" ? difference(zone: zone, date: date) : "")
                    .font(.caption2).multilineTextAlignment(.center).lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 16, alignment: .top)
            }
        }.foregroundStyle(Color.readable(on: role == "Home" ? homeColor : destinationColor)).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(hex: role == "Home" ? homeColor : destinationColor), in: RoundedRectangle(cornerRadius: 14))
            .modifier(TripCityLongPress(enabled: !selectable) { picker = role == "Home" ? "home" : "destination" })
    }

    // Compare each city's civil date with Home's civil date at the chosen instant.
    private func comparisonDay(_ date: Date, zone: String) -> String? {
        var homeCalendar = Calendar(identifier: .gregorian)
        homeCalendar.timeZone = TimeZone(identifier: clock.homeTimeZoneID) ?? .gmt
        var cityCalendar = homeCalendar
        cityCalendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let homeDay = calendar.date(from: homeCalendar.dateComponents([.year, .month, .day], from: date)),
              let cityDay = calendar.date(from: cityCalendar.dateComponents([.year, .month, .day], from: date)),
              let days = calendar.dateComponents([.day], from: homeDay, to: cityDay).day else { return nil }
        switch days {
        case 0: return nil
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return "\(abs(days)) days \(days > 0 ? "ahead" : "behind")"
        }
    }
    private func comparisonDate(_ date: Date, zone: String) -> String {
        let dateText = TimeEngine.compactDate(date, timeZoneID: zone)
        return comparisonDay(date, zone: zone).map { $0 + " · " + dateText } ?? dateText
    }
    private func time(_ date: Date, zone: String) -> String { let f = DateFormatter(); f.timeZone = TimeZone(identifier: zone); f.dateFormat = clock.use24 ? "HH:mm" : "h:mm a"; return f.string(from: date) }
    private func difference(zone: String, date: Date) -> String { let n = ((TimeZone(identifier: zone)?.secondsFromGMT(for: date) ?? 0) - (TimeZone(identifier: clock.homeTimeZoneID)?.secondsFromGMT(for: date) ?? 0)) / 60; return n == 0 ? "Same time" : "\(abs(n)/60)h\(abs(n)%60 == 0 ? "" : " \(abs(n)%60)m") \(n > 0 ? "ahead" : "behind")" }
}
private struct TripCityLongPress: ViewModifier {
    let enabled: Bool
    let edit: () -> Void
    @GestureState private var pressing = false
    @State private var activation = 0
    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
        content
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(pressing ? 0.97 : 1)
            .brightness(pressing ? -0.025 : 0)
            .overlay(alignment: .topTrailing) {
                if pressing {
                    Image(systemName: "pencil.circle.fill").foregroundStyle(.blue)
                        .padding(6).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .animation(.easeOut(duration: 0.12), value: pressing)
            .gesture(LongPressGesture(minimumDuration: 0.5, maximumDistance: 12)
                .updating($pressing) { value, state, _ in state = value }
                .onEnded { _ in activate() })
            .sensoryFeedback(.impact(weight: .light), trigger: activation)
            .accessibilityHint(enabled ? "Touch and hold to change city" : "")
            .accessibilityActions { Button("Change city") { activate() } }
        } else { content }
    }
    private func activate() { activation += 1; edit() }
}
struct TripCityPicker: View {
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let select: (City) -> Void
    var body: some View { NavigationStack { List { if query.isEmpty { Text("Search for a city") } else { ForEach(CitySearch.search(query, in: clock.allCities)) { city in Button(city.label) { select(city) } } } }.searchable(text: $query).navigationTitle("Choose city").toolbar { ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } }.tripToolbarBackground() } } }
}

#if DEBUG
extension TravelDashboard {
    init(tutorialCurrency currency: ConverterStore, trip: TripStore, weather: TripWeatherStore, shift: Double = 0, reordering: Bool = false, initialTool: DashboardTool? = nil) {
        self.init(currency: currency)
        _trip = StateObject(wrappedValue: trip)
        _weather = StateObject(wrappedValue: weather)
        _shift = State(initialValue: shift)
        _tool = State(initialValue: initialTool)
        _editingCities = State(initialValue: reordering)
    }
}
#endif



enum DashboardTool: String, Identifiable {
    case currency, translate, world, units, weather, documents, readiness
    var id: String { rawValue }
}
