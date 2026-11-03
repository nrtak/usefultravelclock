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
    @AppStorage("trip-tab-order") private var legacySavedTabs = "0,1,2"
    @AppStorage("trip-tab-order-v2") private var savedTabs = ""
    @State private var editingHome = false
    @State private var editingTabs = false
    @ScaledMetric(relativeTo: .title2) private var comparisonTimeWidth: CGFloat = 110
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
        .overlay { if phase != .active { Color(.systemBackground).ignoresSafeArea().overlay(Label("Timi Clock", systemImage: "lock").font(.title)) } }
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
        .onAppear {
            if savedTabs.isEmpty {
                savedTabs = DashboardTab.migratingLegacy(legacySavedTabs)
                if tab == 2 { tab = DashboardTab.time.rawValue }
            }
            repairTabSelection(); routeInbox()
        }
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
                home.navigationTitle("Home").toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editingHome ? "Done" : "Customize") {
                            if editingHome { editingHome = false } else { customizingHome = true }
                        }.tripToolbarButtonStyle().accessibilityLabel(editingHome ? "Finish editing Home" : "Customize Home")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if editingHome { Button { customizingHome = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add Home card") }
                        homeMenu
                    }
                }
            }
        case .trip:
            NavigationStack {
                TravelRecordsView(currency: currency, cities: readinessCities, acceptsIncomingDocuments: tab == 1 && !hasModal)
                    .navigationTitle("My Trip")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
        case .time:
            NavigationStack {
                world.navigationTitle("Time")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
        case .translate:
            NavigationStack {
                TripTranslateView(active: phase == .active && tab == DashboardTab.translate.rawValue && !hasModal && !editingTabs)
                    .navigationTitle("Translate")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { settingsButton } }
            }
        }
    }
    private var settingsButton: some View {
        Button { settings = true } label: { Image(systemName: "gearshape") }
            .tripToolbarButtonStyle().accessibilityLabel("Settings")
    }
    private var homeMenu: some View {
        Menu {
            Button { tool = .currency } label: { Label("Currency", systemImage: "banknote") }
            Button { tool = .weather } label: { Label("Weather", systemImage: "cloud.sun") }
            Button { tool = .documents } label: { Label("Documents", systemImage: "folder") }
            Button { tool = .readiness } label: { Label("Before you leave", systemImage: "checklist") }
            Divider()
            Button { settings = true } label: { Label("Settings", systemImage: "gearshape") }
        } label: { Image(systemName: "ellipsis") }
            .tripToolbarButtonStyle().accessibilityLabel("More Home actions")
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
            if picker == "home" {
                clock.edit { clock.homeMode = .manual; clock.homeCityID = city.id }
            } else if let selection = picker, selection.hasPrefix("city:") {
                let previous = String(selection.dropFirst(5))
                if city.id != previous && !clock.replaceComparisonCity(previous, with: city.id, destinationID: destinationID) {
                    return "This city is already shown or is no longer available to change. Choose another city."
                }
            } else { destinationID = city.id }
            picker = nil
            return nil
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
        case .clocks:
            if DashboardTab.decode(savedTabs).contains(.time) { tab = DashboardTab.time.rawValue }
            else { tool = .world }
        case .currency: tool = .currency
        case .trip: openTrip()
        case .weather: tool = .weather
        case .documents: tool = .documents
        case .readiness: tool = .readiness
        }
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
                        world.navigationTitle("Time")
                            .sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) { cityPicker }
                    case .weather: TripWeatherSearchView(home: clock.homeMode == .manual ? clock.homeCity : nil, destination: destination)
                    case .documents: TripDocumentsView()
                    case .readiness: TripReadinessView(currency: currency, cities: readinessCities)
                    case .trip: TravelRecordsView(currency: currency, cities: readinessCities).navigationTitle("My Trip")
                    case .currency: EmptyView()
                    }
                }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { tool = nil } } }
            }
        }
    }
    private var readinessCities: [City] {
        var seen = Set<String>()
        return [clock.homeMode == .manual ? clock.homeCity : nil, destination].compactMap { $0 }.filter { seen.insert($0.id).inserted }
    }
    private var comparisonCities: [City] {
        clock.comparisonCities(destinationID: destinationID)
    }
    private var world: some View {
        TripVisibleTimeline(interval: 30, enabled: phase == .active && ((tab == DashboardTab.time.rawValue && !hasModal && !editingTabs) || (tool == .world && picker == nil && !editingTabs))) { context in
            let date = context.date.addingTimeInterval(shift * 3600)
            ScrollView {
                VStack(spacing: 16) {
                    comparisonControls
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            TripSectionLabel(title: "City clocks", symbol: "globe")
                            Spacer(minLength: 8)
                            if editingCities || !comparisonCities.isEmpty {
                                Button(editingCities ? "Done" : "Edit") { editingCities.toggle() }
                                    .tripButtonStyle()
                                    .accessibilityLabel(editingCities ? "Finish editing cities" : "Edit and reorder cities")
                            }
                        }.padding(.bottom, 6)
                        if editingCities && !comparisonCities.isEmpty {
                            Text("Drag cities to reorder. Tap a pencil to change a city.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
                        }
                        primaryClock(role: "Home", name: clock.homeMode == .manual ? clock.homeCity?.name ?? "Home" : "Device time",
                                     location: clock.homeMode == .manual ? clock.homeCity?.clockLocationLabel ?? "Choose a city" : "Device time zone",
                                     zone: clock.homeTimeZoneID, at: date, selection: "home")
                        Divider()
                        primaryClock(role: "Destination", name: destination?.name ?? "Choose city",
                                     location: destination?.clockLocationLabel ?? "Choose a city", zone: destination?.timeZoneID,
                                     at: date, selection: "destination")
                        ForEach(comparisonCities) { city in
                            Divider()
                            reorderableCity(city, at: date)
                        }
                    }.tripPanel(accent: .gray)
                }.padding(12)
            }.scrollBounceBehavior(.basedOnSize)
                .background(Color(.systemGroupedBackground))
        }.navigationBarTitleDisplayMode(.inline)
    }
    private var comparisonControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Compare times").font(.headline).fixedSize()
                    Spacer(minLength: 12)
                    returnToNowButton.fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare times").font(.headline)
                    returnToNowButton
                }
            }
            Slider(value: $shift, in: -24...24, step: 0.5)
                .overlay(alignment: .bottom) {
                    Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 2, height: 7)
                        .offset(y: 4).allowsHitTesting(false).accessibilityHidden(true)
                }
                .accessibilityLabel("Compare city times")
                .accessibilityValue(shift == 0 ? "Now, zero hours" : "\(shift.formatted()) hours from now")
            Text(shift == 0 ? "Live time" : "\(abs(shift).formatted()) \(abs(shift) == 1 ? "hour" : "hours") \(shift > 0 ? "later" : "earlier")")
                .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.tripPanel()
    }
    private var returnToNowButton: some View {
        Button("Return to now") { shift = 0 }.tripButtonStyle().disabled(shift == 0)
    }

    @ViewBuilder
    private func reorderableCity(_ city: City, at date: Date) -> some View {
        if editingCities {
            comparisonCityRow(city, at: date)
                .draggable(city.id)
                .dropDestination(for: String.self) { items, _ in
                    guard items.count == 1, let moved = items.first else { return false }
                    return withAnimation { clock.moveComparisonCity(moved, to: city.id, destinationID: destinationID) }
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
        VStack(alignment: .leading, spacing: 0) {
            if editingCities {
                HStack {
                    Image(systemName: "line.3.horizontal").foregroundStyle(.secondary).accessibilityHidden(true)
                    Spacer()
                    Button { picker = "city:" + city.id } label: {
                        Image(systemName: "pencil").frame(minWidth: 44, minHeight: 44)
                    }.tripButtonStyle().accessibilityLabel("Change " + city.name)
                }
            }
            comparisonClockContent(name: city.name, location: city.clockLocationLabel, zone: city.timeZoneID, at: date)
        }
        .contentShape(Rectangle())
        .rotationEffect(.degrees(editingCities && !reduceMotion ? 0.5 : 0))
        .animation(editingCities && !reduceMotion ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : .default, value: editingCities)
        .sensoryFeedback(.impact(weight: .light), trigger: cityEditFeedback)
        .accessibilityElement(children: editingCities ? .contain : .combine)
        .accessibilityHint(editingCities ? "Use Move up or Move down actions to reorder" : "Use Reorder cities or Change city actions")
    }
    private func moveComparisonCity(_ id: String, by offset: Int) {
        let cities = comparisonCities
        guard let index = cities.firstIndex(where: { $0.id == id }), cities.indices.contains(index + offset) else { return }
        clock.moveComparisonCity(id, to: cities[index + offset].id, destinationID: destinationID)
    }
    private func primaryClock(role: String, name: String, location: String, zone: String?, at date: Date, selection: String) -> some View {
        Button { picker = selection } label: {
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        clockRole(role).fixedSize(horizontal: true, vertical: false)
                        if role == "Destination", let zone, clock.showDifference {
                            Text(difference(zone: zone, date: date)).font(.subheadline).foregroundStyle(.secondary).fixedSize()
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        clockRole(role)
                        if role == "Destination", let zone, clock.showDifference {
                            Text(difference(zone: zone, date: date)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                comparisonClockContent(name: name, location: location, zone: zone, at: date)
            }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in picker = selection })
            .accessibilityElement(children: .combine)
            .accessibilityHint("Choose \(role.lowercased()) city")
    }
    private func clockRole(_ role: String) -> some View {
        Label(role, systemImage: "pencil")
            .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(Color.readable(on: role == "Home" ? homeColor : destinationColor))
            .background(Color(hex: role == "Home" ? homeColor : destinationColor), in: Capsule())
    }
    private func alignedComparisonTimeWidth(at date: Date) -> CGFloat {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 22 * comparisonTimeWidth / 110, weight: .semibold)
        let zones = [clock.homeTimeZoneID, destination?.timeZoneID].compactMap { $0 } + comparisonCities.map(\.timeZoneID)
        let measured = zones.map { (time(date, zone: $0) as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return max(comparisonTimeWidth, measured.rounded(.up) + 4)
    }
    private func comparisonClockContent(name: String, location: String, zone: String?, at date: Date) -> some View {
        ViewThatFits(in: .horizontal) {
            if typeSize < .xxLarge {
                HStack(spacing: 12) {
                    comparisonCityHeading(name: name, location: location)
                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                    comparisonClockReading(zone: zone, at: date, alignment: .trailing)
                        .frame(width: alignedComparisonTimeWidth(at: date), alignment: .trailing)
                    comparisonAnalogClock(zone: zone, at: date)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                comparisonCityHeading(name: name, location: location)
                HStack(alignment: .center, spacing: 12) {
                    comparisonAnalogClock(zone: zone, at: date)
                    comparisonClockReading(zone: zone, at: date, alignment: .leading)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 10)
    }
    private func comparisonCityHeading(name: String, location: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Text(location).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func comparisonClockReading(zone: String?, at date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(zone.map { time(date, zone: $0) } ?? "—")
                .font(.title2.weight(.semibold)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            if let zone, clock.showDate || clock.showWeekday {
                Text(TimeEngine.compactDate(date, timeZoneID: zone, date: clock.showDate, weekday: clock.showWeekday))
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    @ViewBuilder
    private func comparisonAnalogClock(zone: String?, at date: Date) -> some View {
        if clock.showAnalog {
            if let zone { TripAnalogClock(date: date, zone: zone).foregroundStyle(.secondary) }
            else { Color.clear.frame(width: 54, height: 54).accessibilityHidden(true) }
        }
    }
    private func time(_ date: Date, zone: String) -> String { let f = DateFormatter(); f.timeZone = TimeZone(identifier: zone); f.dateFormat = clock.use24 ? "HH:mm" : "h:mm a"; return f.string(from: date) }
    private func difference(zone: String, date: Date) -> String { let n = ((TimeZone(identifier: zone)?.secondsFromGMT(for: date) ?? 0) - (TimeZone(identifier: clock.homeTimeZoneID)?.secondsFromGMT(for: date) ?? 0)) / 60; return n == 0 ? "Same time" : "\(abs(n)/60)h\(abs(n)%60 == 0 ? "" : " \(abs(n)%60)m") \(n > 0 ? "ahead" : "behind")" }
}
struct TripCityPicker: View {
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectionError: String?
    let select: (City) -> String?
    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty { Text("Search for a city") }
                else {
                    ForEach(CitySearch.search(query, in: clock.allCities)) { city in
                        Button(city.label) { selectionError = select(city) }
                    }
                }
            }.searchable(text: $query).navigationTitle("Choose city")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } }
                        .tripToolbarBackground()
                }
                .alert("Choose another city", isPresented: Binding(get: { selectionError != nil }, set: { if !$0 { selectionError = nil } })) {
                    Button("OK") { selectionError = nil }
                } message: { Text(selectionError ?? "") }
        }
    }
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
    case currency, world, weather, documents, readiness, trip
    var id: String { rawValue }
    var accent: Color {
        switch self {
        case .currency: return .blue
        case .trip: return .teal
        case .world: return .indigo
        case .weather: return .orange
        case .documents: return .purple
        case .readiness: return .green
        }
    }
}
