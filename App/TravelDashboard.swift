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
    @AppStorage("trip-selected-tab") private var tab = 0
    @AppStorage("trip-tab-order") private var savedTabOrder = "0,1,2,3,4"
    @State private var editingTabs = false
    @State private var tabEditFeedback = 0
    private let tabTitles = ["Home", "Conversions", "World Time", "My Trip", "Translate"]
    private let tabSymbols = ["house", "banknote", "clock", "suitcase", "character.bubble"]
    private var tabOrder: [Int] {
        var result: [Int] = []
        for id in savedTabOrder.split(separator: ",").compactMap({ Int($0) }) where (0...4).contains(id) && !result.contains(id) {
            result.append(id)
        }
        return result + (0...4).filter { !result.contains($0) }
    }
    @State private var picker: String?
    @State private var settings = false
    @State private var shift: Double = 0
    @FocusState private var homeEditingSide: AmountSide?
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { home.navigationTitle("Trip Info").toolbar { Button { settings = true } label: { Image(systemName: "gearshape") } } }.tabItem { Label("Home", systemImage: "house") }.toolbar(.hidden, for: .tabBar).tag(0)
            CurrencyConverterView(store: currency, onBack: { tab = 0 }).tabItem { Label("Conversions", systemImage: "banknote") }.toolbar(.hidden, for: .tabBar).tag(1)
            NavigationStack { world.navigationTitle("World Time").toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Back") { tab = 0 }  }.tripToolbarBackground() } }.tabItem { Label("World Time", systemImage: "clock") }.toolbar(.hidden, for: .tabBar).tag(2)
            NavigationStack { TravelRecordsView().navigationTitle("My Trip").toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Back") { tab = 0 }  }.tripToolbarBackground() } }.tabItem { Label("My Trip", systemImage: "suitcase") }.toolbar(.hidden, for: .tabBar).tag(3)
            NavigationStack { TripTranslateView().navigationTitle("Translate").toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Back") { tab = 0 }  }.tripToolbarBackground() } }.tabItem { Label("Translate", systemImage: "character.bubble") }.toolbar(.hidden, for: .tabBar).tag(4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomTabs }
        .overlay { if phase != .active { Color(.systemBackground).ignoresSafeArea().overlay(Label("Trip Info", systemImage: "lock").font(.title)) } }
        .environmentObject(weather)
        .environmentObject(trip)
        .sheet(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } })) {
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
        .sheet(isPresented: $settings) { TripSettingsView() }
        .alert("Couldn’t complete action", isPresented: Binding(get: { trip.error != nil }, set: { if !$0 { trip.error = nil } })) { Button("OK") { trip.error = nil } } message: { Text(trip.error ?? "") }
        .onChange(of: tab) { _, _ in shift = 0; homeEditingSide = nil }
        .onChange(of: phase) { _, value in
            if value == .background { trip.lock(); shift = 0; editingTabs = false }
            if value == .active { Task { await trip.unlock() } }
        }
        .task { await trip.unlock(); await currency.refresh() }
    }

    private var bottomTabs: some View {
        VStack(spacing: 4) {
            if editingTabs {
                HStack {
                    Text("Drag tabs to reorder").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Done") { editingTabs = false }
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.padding(.horizontal, 16)
            }
            HStack(spacing: 0) {
                ForEach(tabOrder, id: \.self) { id in
                    reorderableTab(id)
                }
            }.padding(.vertical, 8)
        }
        .background(.regularMaterial)
        .sensoryFeedback(.impact(weight: .light), trigger: tabEditFeedback)
    }
    @ViewBuilder
    private func reorderableTab(_ id: Int) -> some View {
        if editingTabs {
            tabButton(id)
                .draggable(String(id))
                .dropDestination(for: String.self) { items, _ in
                    guard let value = items.first, let moved = Int(value),
                          let from = tabOrder.firstIndex(of: moved),
                          let to = tabOrder.firstIndex(of: id), from != to else { return false }
                    var order = tabOrder
                    order.remove(at: from)
                    order.insert(moved, at: to)
                    withAnimation { savedTabOrder = order.map(String.init).joined(separator: ",") }
                    return true
                }
                .accessibilityActions {
                    Button("Move left") { moveTab(id, by: -1) }
                    Button("Move right") { moveTab(id, by: 1) }
                }
        } else {
            tabButton(id)
                .onLongPressGesture(minimumDuration: 0.6) {
                    homeEditingSide = nil
                    editingTabs = true
                    tabEditFeedback += 1
                }
                .accessibilityAction(named: "Reorder tabs") { editingTabs = true }
        }
    }
    private func tabButton(_ id: Int) -> some View {
        Button {
            if !editingTabs { tab = id }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tabSymbols[id]).font(.system(size: 25, weight: .medium))
                    .frame(height: 30)
                    .rotationEffect(.degrees(editingTabs ? (id.isMultiple(of: 2) ? 2 : -2) : 0))
                    .animation(editingTabs ? .easeInOut(duration: 0.15).repeatForever(autoreverses: true) : .default, value: editingTabs)
                Text(tabTitles[id]).font(.caption2.weight(tab == id ? .semibold : .regular))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(tab == id ? Color.blue : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 2)
            .background(tab == id ? Color.blue.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tabTitles[id])
        .accessibilityAddTraits(tab == id ? .isSelected : [])
        .accessibilityHint(editingTabs ? "Drag to change tab order" : "Touch and hold to reorder tabs")
    }
    private func moveTab(_ id: Int, by offset: Int) {
        var order = tabOrder
        guard let index = order.firstIndex(of: id), order.indices.contains(index + offset) else { return }
        order.swapAt(index, index + offset)
        savedTabOrder = order.map(String.init).joined(separator: ",")
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    private var home: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView { homeContent(compact: true) }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDisabled(homeEditingSide == nil && !typeSize.isAccessibilitySize)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: homeEditingSide) { _, side in
                        if side != nil { withAnimation { proxy.scrollTo("home-currency", anchor: .top) } }
                    }
            }.frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }.navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if homeEditingSide != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        TripNavigationButton(title: "Done") { homeEditingSide = nil }
                    }.tripToolbarBackground()
                }
            }
    }
    private func homeContent(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            TimelineView(.periodic(from: .now, by: 30)) { context in clocks(at: context.date, selectable: true, compact: compact) }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TripSectionLabel(title: "Currency", symbol: "banknote")
                    Spacer(minLength: 4)
                    Button { homeEditingSide = nil; tab = 1 } label: {
                        Label("Full converter", systemImage: "arrow.up.right")
                            .font(.caption.weight(.semibold)).frame(minHeight: 44)
                    }.buttonStyle(.bordered).tint(.blue)
                        .accessibilityHint("Open currency tools, multiple prices, live camera and saved conversions")
                }
                HStack {
                    quick(.source)
                    Button { homeEditingSide = nil; currency.swap() } label: {
                        Image(systemName: "arrow.left.arrow.right").frame(width: 44, height: 44)
                    }.buttonStyle(.plain).foregroundStyle(.blue).accessibilityLabel("Swap currencies")
                    quick(.target)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.detail)
                    TripRateStatus(store: currency)
                    if let snapshot = currency.snapshot { TripRefreshStamp(success: currency.lastManualRefresh, fallback: "Checked " + snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)) }
                }.font(.caption2).foregroundStyle(.secondary)
            }.tripPanel().id("home-currency")
            TripWeatherCard(home: clock.homeMode == .manual ? clock.homeCity : nil, destination: destination)
            Button { tab = 3 } label: {
                HStack {
                    Image(systemName: "suitcase.fill").font(.title2).foregroundStyle(.orange)
                        .frame(width: 40, height: 44).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    TimelineView(.periodic(from: .now, by: 60)) { context in nextTrip(at: context.date) }
                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }.padding(compact ? 10 : 12)
            }.buttonStyle(.plain).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }.padding(12).fixedSize(horizontal: false, vertical: true)
    }
    private func quick(_ side: AmountSide) -> some View {
        let code = side == .source ? currency.source : currency.target
        return VStack(alignment: .leading) {
            Text(code).font(.caption)
            HStack(spacing: 4) {
                Text(Currency.named(code).symbol)
                TextField("Amount", text: Binding(
                    get: { currency.fieldText(for: side, focused: homeEditingSide == side) },
                    set: { currency.edit($0, side: side) }
                ))
                .focused($homeEditingSide, equals: side)
                .keyboardType(.decimalPad).font(.title2.weight(.semibold)).monospacedDigit()
                .accessibilityLabel("\(side == .source ? "From" : "To") amount in \(Currency.named(code).name)")
            }
        }.padding(8).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10)).frame(maxWidth: .infinity)
    }
    private func nextTrip(at now: Date) -> some View {
        let next = trip.records.filter { $0.start >= now }.min { $0.start < $1.start }
        return VStack(alignment: .leading, spacing: 3) {
            Text(next == nil ? "My Trip" : "My Trip · Next").font(.caption)
            Text(next.map { $0.name.isEmpty ? $0.kind : $0.name } ?? "View travel details").font(.headline).lineLimit(1)
            if let next {
                Text((next.kind == "Hotel" ? "Check-in · " : "Departure · ") + next.timeLabel(start: true))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var world: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let date = context.date.addingTimeInterval(shift * 3600)
            ScrollView {
            VStack(spacing: 10) {
                Text(shift == 0 ? "Live time" : "Preview — all times shifted").font(.headline)
                Text("Hold a city to edit").font(.caption2).foregroundStyle(.secondary)
                clocks(at: date, selectable: false)
                ForEach(Array(clock.selectedCities.filter { $0.id != destinationID && $0.id != clock.homeCityID }.prefix(3))) { city in
                    HStack { VStack(alignment: .leading) { Text(city.name).font(.headline); Text(city.country).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(time(date, zone: city.timeZoneID)).font(.title3).monospacedDigit() }.padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .modifier(TripCityLongPress(enabled: true) { picker = "city:" + city.id })
                }
                VStack { HStack { Text("Compare all cities"); Spacer(); Button("Return to now") { shift = 0 }.disabled(shift == 0) }; Slider(value: $shift, in: -24...24, step: 0.5); Text(shift == 0 ? "Live time" : "Preview: \(shift.formatted()) hours from now").font(.caption) }.padding().background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                TripArtwork(symbol: "globe")
            Spacer(minLength: 0)
            }.padding(12)
            }.scrollBounceBehavior(.basedOnSize)
        }.navigationBarTitleDisplayMode(.inline)
    }
    private func clocks(at date: Date, selectable: Bool, compact: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
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
            Text(time(date, zone: zone)).frame(maxWidth: .infinity).font(.title2.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
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
                Text(TimeEngine.compactDate(date, timeZoneID: zone)).font(.caption).frame(maxWidth: .infinity)
                Text(role == "Destination" ? difference(zone: zone, date: date) : "")
                    .font(.caption2).multilineTextAlignment(.center).lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 16, alignment: .top)
            }
        }.foregroundStyle(Color.readable(on: role == "Home" ? homeColor : destinationColor)).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(hex: role == "Home" ? homeColor : destinationColor), in: RoundedRectangle(cornerRadius: 14))
            .modifier(TripCityLongPress(enabled: !selectable) { picker = role == "Home" ? "home" : "destination" })
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
