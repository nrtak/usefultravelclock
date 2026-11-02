import SwiftUI
import UIKit

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
    @AppStorage("trip-tab-order") private var savedTabs = DashboardTab.defaults
    @State private var editingHome = false
    @State private var editingTabs = false
    @ScaledMetric(relativeTo: .title) private var comparisonColumnWidth: CGFloat = 170
    @State private var editingCities = false
    @State private var cityEditFeedback = 0
    @State private var customizingHome = false
    @State private var customizingTabs = false
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
            ForEach(DashboardTab.decode(savedTabs)) { item in
                tabContent(item)
                    .toolbar(editingTabs ? .hidden : .automatic, for: .tabBar)
                    .tabItem { Label(item.title, systemImage: item.symbol) }.tag(item.rawValue)
            }
        }
        .background {
            TripTabBarHold(enabled: phase == .active && !hasModal && !editingTabs) {
                guard phase == .active && !hasModal && !editingTabs else { return }
                editingHome = false
                if typeSize.isAccessibilitySize { customizingTabs = true }
                else { editingTabs = true }
            }.frame(width: 0, height: 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editingTabs {
                DashboardTabEditor(savedTabs: $savedTabs, selection: $tab) { editingTabs = false }
            }
        }
        .tripNavigationAppearance()
        .tint(.blue)
        .overlay { if phase != .active { Color(.systemBackground).ignoresSafeArea().overlay(Label("Pockaway", systemImage: "lock").font(.title)) } }
        .sheet(isPresented: Binding(get: { picker != nil && tool == nil }, set: { if !$0 { picker = nil } }), onDismiss: routeInbox) { cityPicker }
        .sheet(isPresented: $customizingHome, onDismiss: routeInbox) { HomeCustomizationView(savedSections: $savedHomeSections, capacity: homeCapacity) }
        .sheet(isPresented: $customizingTabs, onDismiss: routeInbox) {
            NavigationStack {
                DashboardTabSettings().toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { customizingTabs = false } }
                }
            }
        }
        .sheet(item: $tool, onDismiss: routeInbox) { selection in toolScreen(selection) }
        .sheet(item: $homeRecord, onDismiss: routeInbox) { RecordEditor(record: $0) }
        .sheet(isPresented: $settings, onDismiss: routeInbox) { TripSettingsView() }
        .sheet(item: $homeDocument, onDismiss: { trip.clearDocumentPreviews(); routeInbox() }) { file in TripDocumentPreviewSheet(url: file.url) }
        .alert("Couldn’t complete action", isPresented: Binding(get: { trip.error != nil }, set: { if !$0 { trip.error = nil } })) { Button("OK") { trip.error = nil } } message: { Text(trip.error ?? "") }
        .onChange(of: documentInbox.url) { _, _ in routeInbox() }
        .onAppear { repairTabSelection(); routeInbox() }
        .onChange(of: savedTabs) { _, _ in repairTabSelection() }
        .onChange(of: typeSize) { _, size in
            if size.isAccessibilitySize && editingTabs {
                editingTabs = false
                if phase == .active && !hasModal { customizingTabs = true }
            }
        }
        .onChange(of: tab) { _, value in shift = 0; editingCities = false; if value != 0 { editingHome = false } }
        .onChange(of: tool) { _, value in if value == nil { shift = 0; editingCities = false; picker = nil } }
        .onChange(of: phase) { _, value in
            if value == .background { editingHome = false; editingTabs = false; homeDocument = nil; trip.lock(); homeRecord = nil; picker = nil; shift = 0; editingCities = false }
            if value == .active { Task { await trip.unlock(); if trip.unlocked { await trip.reminders.synchronize(records: trip.records) }; routeInbox() } }
        }
        .task { await trip.unlock(); await currency.refresh() }
        // Wrap the sheet presenters too: their content needs the same stores as the tabs.
        .environmentObject(weather)
        .environmentObject(trip)
    }

    @ViewBuilder
    private func tabContent(_ item: DashboardTab) -> some View {
        switch item {
        case .home:
            NavigationStack {
                home.navigationTitle("Pockaway").toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editingHome ? "Done" : "Customize") {
                            if editingHome { editingHome = false } else { customizingHome = true }
                        }.tripToolbarButtonStyle().accessibilityLabel(editingHome ? "Finish editing Home" : "Customize Home")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if editingHome { Button { customizingHome = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add Home card") }
                        settingsButton
                    }
                }
            }
        case .trip:
            NavigationStack {
                TravelRecordsView(currency: currency, cities: readinessCities, acceptsIncomingDocuments: tab == 1 && !hasModal)
                    .navigationTitle("My Trip")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
        case .tools:
            NavigationStack {
                tools.navigationTitle("Tools")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
        }
    }
    private var settingsButton: some View {
        Button { settings = true } label: { Image(systemName: "gearshape") }
            .tripToolbarButtonStyle().accessibilityLabel("Settings")
    }
    private func openTrip() {
        if DashboardTab.decode(savedTabs).contains(.trip) { tab = DashboardTab.trip.rawValue }
        else { tool = .trip }
    }
    private func repairTabSelection() {
        let visible = DashboardTab.decode(savedTabs)
        if !visible.contains(where: { $0.rawValue == tab }) { tab = visible[0].rawValue }
    }

    private var hasModal: Bool { tool != nil || homeRecord != nil || homeDocument != nil || picker != nil || settings || customizingHome || customizingTabs }
    private func routeInbox() {
        guard phase == .active, documentInbox.url != nil, !hasModal else { return }
        editingHome = false; editingTabs = false
        openTrip()
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
        DashboardHome(currency: currency, savedSections: $savedHomeSections, capacity: $homeCapacity, active: phase == .active && tab == 0 && !hasModal && !editingHome && !editingTabs,
            editingLayout: editingHome, beginEditing: {
                guard phase == .active && !hasModal && tab == 0 else { return }
                editingTabs = false; editingHome = true
            },
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
        case .trip: openTrip()
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
                TripFeatureIcon(symbol: symbol, color: selection.accent, size: 44)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(selection.accent)
            }.foregroundStyle(.primary).padding(.vertical, 10)
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
                    case .trip: TravelRecordsView(currency: currency, cities: readinessCities).navigationTitle("My Trip")
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
                        .font(.footnote).foregroundStyle(.secondary)
                    if editingCities {
                        Spacer()
                        Button("Done") { editingCities = false }.font(.subheadline).frame(minHeight: 44)
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
                    .accessibilityValue(shift == 0 ? "Now, zero hours" : "\(shift.formatted()) hours from now"); Text(shift == 0 ? "Now · 0 hours" : "\(shift > 0 ? "+" : "")\(shift.formatted()) hours from now").font(.subheadline).monospacedDigit() }.padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
        (typeSize >= .xxLarge ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
            if editingCities {
                Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                Button { picker = "city:" + city.id } label: {
                    Image(systemName: "pencil").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("Change " + city.name)
            }
            VStack(alignment: .leading) {
                Text(city.name).font(.title2.weight(.bold)).lineLimit(2)
                Text(city.clockLocationLabel).font(.subheadline).lineLimit(2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(time(date, zone: city.timeZoneID)).font(.title2.weight(.semibold)).monospacedDigit()
                if let day = comparisonDay(date, zone: city.timeZoneID) {
                    Text(day).font(.subheadline).foregroundStyle(.secondary)
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
    @ViewBuilder
    private func clocks(at date: Date, selectable: Bool) -> some View {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold)
        let strings = [time(date, zone: clock.homeTimeZoneID), destination.map { time(date, zone: $0.timeZoneID) } ?? "—"]
        let measured = strings.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let columnWidth = max(comparisonColumnWidth, (measured * comparisonColumnWidth / 170).rounded(.up) + 24)
        if typeSize.isAccessibilitySize {
            stackedClocks(at: date, selectable: selectable)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    homeComparisonClock(at: date, selectable: selectable).frame(width: columnWidth)
                    destinationComparisonClock(at: date, selectable: selectable).frame(width: columnWidth)
                }
                stackedClocks(at: date, selectable: selectable)
            }
        }
    }
    private func stackedClocks(at date: Date, selectable: Bool) -> some View {
        VStack(spacing: 12) {
            homeComparisonClock(at: date, selectable: selectable)
            destinationComparisonClock(at: date, selectable: selectable)
        }
    }
    private func homeComparisonClock(at date: Date, selectable: Bool) -> some View {
        clockBox(role: "Home", name: clock.homeMode == .manual ? clock.homeCity?.name ?? "Home" : "Device time",
                 location: clock.homeMode == .manual ? clock.homeCity?.clockLocationLabel ?? "Choose a city" : "Device time zone",
                 zone: clock.homeTimeZoneID, date: date, selectable: selectable)
    }
    private func destinationComparisonClock(at date: Date, selectable: Bool) -> some View {
        clockBox(role: "Destination", name: destination?.name ?? "Choose city", location: destination?.clockLocationLabel ?? "Choose a city", zone: destination?.timeZoneID, date: date, selectable: selectable)
    }
    private func clockBox(role: String, name: String, location: String, zone: String?, date: Date, selectable: Bool) -> some View {
        let displayedTime = zone.map { time(date, zone: $0) } ?? "—"
        return VStack(spacing: 8) {
            Text(role).font(.subheadline).frame(maxWidth: .infinity)
            if selectable {
                Button { picker = role == "Home" ? "home" : "destination" } label: {
                    Label(name, systemImage: "pencil").font(.title2.weight(.bold)).lineLimit(2, reservesSpace: true)
                }.frame(maxWidth: .infinity).buttonStyle(.plain)
            } else {
                Text(name).font(.title2.weight(.bold)).lineLimit(2, reservesSpace: true).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            Text(location).font(.subheadline).lineLimit(2, reservesSpace: true).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            ViewThatFits(in: .horizontal) {
                Text(displayedTime).fixedSize(horizontal: true, vertical: false)
                Text(displayedTime).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }.font(.title.weight(.semibold)).monospacedDigit()
                .frame(maxWidth: .infinity).accessibilityLabel(role + " time " + displayedTime)
            if clock.showAnalog {
                Group {
                    if let zone { TripAnalogClock(date: date, zone: zone) }
                    else { Color.clear.frame(width: 54, height: 54).accessibilityHidden(true) }
                }.frame(maxWidth: .infinity)
            }
            Text(zone.map { comparisonDate(date, zone: $0) } ?? "Choose a city")
                .font(.subheadline).lineLimit(2, reservesSpace: true).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text(role == "Destination" ? zone.map { difference(zone: $0, date: date) } ?? "" : "")
                .font(.subheadline).lineLimit(2, reservesSpace: true).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }.foregroundStyle(Color.readable(on: role == "Home" ? homeColor : destinationColor))
            .frame(maxWidth: .infinity, alignment: .top).padding(12)
            .background(Color(hex: role == "Home" ? homeColor : destinationColor), in: RoundedRectangle(cornerRadius: 14))
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
    case currency, translate, world, units, weather, documents, readiness, trip
    var id: String { rawValue }
    var accent: Color {
        switch self {
        case .currency: return .blue
        case .translate, .trip: return .teal
        case .world: return .indigo
        case .units, .weather: return .orange
        case .documents: return .purple
        case .readiness: return .green
        }
    }
}
