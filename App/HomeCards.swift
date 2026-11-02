import SwiftUI
import UIKit

struct DashboardHome: View {
    @ObservedObject var currency: ConverterStore
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @EnvironmentObject private var trip: TripStore
    @Binding var savedSections: String
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 200
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var clockTimeWidth: CGFloat = 110
    @ScaledMetric(relativeTo: .body) private var clockRowHeight: CGFloat = 72
    private let analogClockSize: CGFloat = 54
    @Binding var capacity: Int
    @State private var editingCurrency = false
    let active: Bool
    var editingLayout = false
    var beginEditing: () -> Void = {}
    let open: (HomeSection) -> Void
    let chooseCity: (String) -> Void
    let openRecord: (TravelRecord) -> Void
    let openDocument: (TripDocument) -> Void
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    var body: some View {
        GeometryReader { geometry in
            let slots = HomeLayout.capacity(height: geometry.size.height, cardHeight: cardHeight)
            let sections = HomeSection.decode(savedSections)
            let displayed = editingCurrency && sections.contains(.currency) ? [.currency] : Array(sections.prefix(slots))
            VStack(spacing: HomeLayout.spacing) {
                ForEach(displayed) { section in
                    Group {
                        if section == .currency || section == .clocks {
                            // Interactive fields must not disappear into the summary fallback.
                            detail(section)
                        } else {
                            ViewThatFits(in: .vertical) {
                                detail(section).fixedSize(horizontal: false, vertical: true)
                                Button { open(section) } label: {
                                    Label(section.title, systemImage: section.symbol).font(.headline)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .allowsHitTesting(!editingLayout)
                    .padding(12).frame(maxWidth: .infinity)
                    .frame(height: editingCurrency ? min(cardHeight, max(0, geometry.size.height - 2 * HomeLayout.padding)) : cardHeight)
                    .background { TripCardBackground(accent: section == .clocks ? .gray : section.accent) }
                    .contentShape(RoundedRectangle(cornerRadius: 22))
                    .onLongPressGesture(minimumDuration: 0.8) {
                        if active && !editingLayout && !editingCurrency { beginEditing() }
                    }
                    .overlay(alignment: .topLeading) {
                        if editingLayout {
                            Button { remove(section) } label: {
                                Image(systemName: "minus.circle.fill").symbolRenderingMode(.palette)
                                    .font(.title3).foregroundStyle(.white, .red).frame(width: 44, height: 44)
                            }.buttonStyle(.plain).offset(x: -8, y: -8).accessibilityLabel("Remove \(section.title) from Home")
                        }
                    }
                    .modifier(TripReorderable(id: "home:\(section.rawValue)", enabled: editingLayout) { source, target in
                        guard let from = homeID(source), let to = homeID(target), from != to else { return false }
                        withAnimation { savedSections = HomeSection.moving(from, to: to, in: savedSections) }
                        return true
                    })
                    .modifier(TripEditingMotion(editing: editingLayout))
                    .accessibilityActions {
                        Button("Edit Home") { beginEditing() }
                        Button("Move up") { move(section, offset: -1) }
                        Button("Move down") { move(section, offset: 1) }
                        Button("Remove from Home") { remove(section) }
                    }
                }
                if !editingCurrency && (sections.isEmpty || slots == 0) {
                    ViewThatFits(in: .vertical) {
                        VStack(spacing: 12) {
                            Text(sections.isEmpty ? "Make Home your own" : "Your tools are always available").font(.headline)
                            Text("Choose your Home cards using Customize. Time, Translate and My Trip have their own tabs. More opens Currency, Weather and other Home actions.").font(.subheadline)
                        }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Color.clear.frame(height: 0)
                    }
                }
            }
            .padding(HomeLayout.padding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .onChange(of: slots, initial: true) { _, value in capacity = value }
            .onChange(of: savedSections) { _, saved in
                if !HomeSection.decode(saved).contains(.currency) { editingCurrency = false }
            }
        }.navigationBarTitleDisplayMode(.inline)
    }
    private func homeID(_ value: String) -> HomeSection? {
        guard value.hasPrefix("home:") else { return nil }
        return HomeSection(rawValue: String(value.dropFirst(5)))
    }
    private func remove(_ section: HomeSection) {
        savedSections = HomeSection.encode(HomeSection.decode(savedSections).filter { $0 != section })
    }
    private func move(_ section: HomeSection, offset: Int) {
        let items = HomeSection.decode(savedSections)
        guard let index = items.firstIndex(of: section), items.indices.contains(index + offset) else { return }
        savedSections = HomeSection.moving(section, to: items[index + offset], in: savedSections)
    }
    @ViewBuilder
    private func detail(_ section: HomeSection) -> some View {
        switch section {
        case .clocks:
            TripVisibleTimeline(interval: 30, enabled: active) { context in
                if typeSize.isAccessibilitySize {
                    ViewThatFits(in: .vertical) {
                        accessibleClocks(at: context.date, showingDates: true).fixedSize(horizontal: false, vertical: true)
                        accessibleClocks(at: context.date, showingDates: false).fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(spacing: 6) {
                        homeClock(at: context.date)
                        Divider()
                        destinationClock(at: context.date)
                    }.frame(maxHeight: .infinity)
                }
            }
        case .currency:
            HomeCurrencyCard(store: currency, active: active, editingChanged: { editingCurrency = $0 }) { open(section) }
        case .trip:
            TripVisibleTimeline(interval: 60, enabled: active) { context in
                let next = TripSummary.record(in: trip.records, at: context.date)
                Button {
                    if let next { openRecord(trip.drafts.first { $0.id == next.id } ?? next) }
                    else { open(section) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        heading(section)
                        Text(next.map { $0.name.isEmpty ? $0.kind : $0.name } ?? "Add your next booking").font(.headline).lineLimit(2)
                        if let next {
                            Text(next.timingLabel(at: context.date) + " · " + next.timeLabel(start: next.start > context.date)).font(.subheadline).lineLimit(2).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityHint("Open booking details")
            }
        case .weather:
            CompactHomeWeather(active: active, home: clock.homeMode == .manual ? clock.homeCity : nil, destination: destination) { open(section) }
        case .documents:
            TripVisibleTimeline(interval: 60, enabled: active) { context in
                let document = trip.summaryDocument(at: context.date)
                Button { if let document { openDocument(document) } else { open(section) } } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        heading(section)
                        Text(document?.name ?? "Add a ticket or confirmation").font(.headline).lineLimit(2)
                        Text("Stored on your iPhone").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
        case .readiness:
            Button { open(section) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    heading(section)
                    Text("Check tickets, rates and offline access before departure.").font(.subheadline).lineLimit(3)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
        }
    }
    private func heading(_ section: HomeSection) -> some View {
        HStack(spacing: 10) {
            TripFeatureIcon(symbol: section.symbol, color: section.accent)
            Text(section.title).font(.headline)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(section.accent)
        }
    }
    private func accessibleClocks(at date: Date, showingDates: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            homeClock(at: date, showingDate: showingDates)
            Divider()
            destinationClock(at: date, showingDate: showingDates)
        }
    }
    private func homeClock(at date: Date, showingDate: Bool = true) -> some View {
        clockColumn(role: "Home", name: clock.homeMode == .manual ? clock.homeCity?.name ?? "Home" : "Device time",
                    city: clock.homeMode == .manual ? clock.homeCity : nil, zone: clock.homeTimeZoneID, date: date, selection: "home", showingDate: showingDate)
    }
    private func destinationClock(at date: Date, showingDate: Bool = true) -> some View {
        clockColumn(role: "Destination", name: destination?.name ?? "Choose city", city: destination,
                    zone: destination?.timeZoneID, date: date, selection: "destination", showingDate: showingDate)
    }
    private func clockTime(at date: Date, zone: String?) -> String {
        guard let zone else { return "—" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: zone)
        formatter.dateFormat = clock.use24 ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
    private func alignedTimeWidth(at date: Date) -> CGFloat {
        let font = UIFont.monospacedDigitSystemFont(ofSize: 22 * clockTimeWidth / 110, weight: .semibold)
        let times = [clockTime(at: date, zone: clock.homeTimeZoneID), clockTime(at: date, zone: destination?.timeZoneID)]
        let measured = times.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        return max(clockTimeWidth, measured.rounded(.up) + 4)
    }
    private func clockColumn(role: String, name: String, city: City?, zone: String?, date: Date, selection: String, showingDate: Bool) -> some View {
        let time = clockTime(at: date, zone: zone)
        let localDate = zone.map { TimeEngine.compactDate(date, timeZoneID: $0) } ?? "Choose destination"
        let location = city?.clockLocationLabel ?? (selection == "home" ? "Device time zone" : "Choose destination")
        let compactLocation = city.map { city in
            guard location != city.country, let region = city.region else { return location }
            return region.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() + ", " + city.country
        } ?? location
        return Button { chooseCity(selection) } label: {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    if showingDate {
                        Text(role + " · " + localDate).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(name).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text(location).font(.subheadline).fixedSize(horizontal: false, vertical: true).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        if clock.showAnalog, let zone { TripAnalogClock(date: date, zone: zone, size: analogClockSize) }
                        Text(time).font(.title2.weight(.semibold)).monospacedDigit()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.title2.weight(.bold)).lineLimit(2)
                        ViewThatFits(in: .horizontal) {
                            Text(location).fixedSize(horizontal: true, vertical: false)
                            Text(compactLocation).lineLimit(2)
                        }.font(.footnote).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(time).font(.title2.weight(.semibold)).monospacedDigit()
                        Text(localDate).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    }.frame(width: alignedTimeWidth(at: date), alignment: .trailing)
                    if clock.showAnalog {
                        Group {
                            if let zone { TripAnalogClock(date: date, zone: zone, size: analogClockSize) }
                            else { Color.clear.frame(width: analogClockSize, height: analogClockSize) }
                        }.foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity, minHeight: clockRowHeight)
            }
        }.buttonStyle(.plain).accessibilityLabel(role + ", " + name + ", " + location + ", " + time + ", " + localDate).accessibilityHint("Choose a city")
    }
}

struct HomeCurrencyCard: View {
    @ObservedObject var store: ConverterStore
    let active: Bool
    let editingChanged: (Bool) -> Void
    let openConverter: () -> Void
    @FocusState private var editingSide: AmountSide?
    private var editing: Bool { editingSide != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if editing { currencyHeading }
            else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        currencyHeading.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 8)
                        fullConverterButton.fixedSize(horizontal: true, vertical: false)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        currencyHeading
                        fullConverterButton.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            HStack(spacing: 12) {
                amountField(.source)
                Button { editingSide = nil; store.swap() } label: {
                    Image(systemName: "arrow.left.arrow.right").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1), in: Circle())
                }.buttonStyle(.plain).foregroundStyle(.blue).accessibilityLabel("Swap currencies")
                amountField(.target)
            }
            if !editing {
                Text("Estimate · " + store.detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Converter") { editingSide = nil; openConverter() }
                    .fontWeight(.semibold).accessibilityLabel("Full converter")
                Spacer()
                Button("Done") { editingSide = nil }
            }
        }
        .onDisappear { editingSide = nil; editingChanged(false) }
        .onChange(of: editing) { _, value in editingChanged(value) }
        .onChange(of: active) { _, value in if !value { editingSide = nil } }
    }

    private var currencyHeading: some View {
        Text("Currency").font(.headline)
    }

    private func amountField(_ side: AmountSide) -> some View {
        let code = side == .source ? store.source : store.target
        return VStack(alignment: .leading, spacing: 4) {
            Text(code).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            TextField("Amount", text: Binding(
                get: { store.fieldText(for: side, focused: editingSide == side) },
                set: { store.edit($0, side: side) }
            ))
            .textFieldStyle(.plain).keyboardType(.decimalPad).monospacedDigit()
            .font(.title2.weight(.semibold)).focused($editingSide, equals: side)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityLabel("\(side == .source ? "From" : "To") amount in \(Currency.named(code).name)")
            .accessibilityIdentifier(side == .source ? "home-currency-amount" : "home-currency-target")
        }.padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: .infinity)
    }

    private var fullConverterButton: some View {
        Button { editingSide = nil; openConverter() } label: {
            HStack(spacing: 8) {
                Text("Full converter").font(.body.weight(.semibold)).multilineTextAlignment(.leading)
                Image(systemName: "arrow.right").font(.body.weight(.semibold))
            }.frame(minHeight: 32)
        }.tripButtonStyle(primary: true).controlSize(.regular)
            .frame(minHeight: 44)
            .accessibilityHint("Open all currency conversion tools")
            .accessibilityIdentifier("home-full-converter")
    }
}

extension HomeSection {
    var accent: Color {
        switch self {
        case .clocks: return .indigo
        case .currency: return .blue
        case .trip: return .teal
        case .weather: return .orange
        case .documents: return .purple
        case .readiness: return .green
        }
    }
}
