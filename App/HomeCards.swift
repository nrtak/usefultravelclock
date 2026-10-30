import SwiftUI

struct DashboardHome: View {
    @ObservedObject var currency: ConverterStore
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @EnvironmentObject private var trip: TripStore
    @Binding var savedSections: String
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 200
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var timeColumnWidth: CGFloat = 150
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
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
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
                            Text("Choose your Home cards using Customize. Every feature is available in My Trip or Tools.").font(.subheadline)
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
                VStack(alignment: .leading, spacing: 6) {
                    clockRow(role: "Home", name: clock.homeMode == .manual ? clock.homeCity?.name ?? "Home" : "Device time", zone: clock.homeTimeZoneID, date: context.date, selection: "home")
                    Divider()
                    clockRow(role: "Destination", name: destination?.name ?? "Choose city", zone: destination?.timeZoneID, date: context.date, selection: "destination")
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
        HStack { Label(section.title, systemImage: section.symbol).font(.headline); Spacer(minLength: 4); Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(.secondary) }
    }
    private func clockRow(role: String, name: String, zone: String?, date: Date, selection: String) -> some View {
        let formatter = DateFormatter()
        formatter.timeZone = zone.flatMap(TimeZone.init(identifier:))
        formatter.dateFormat = clock.use24 ? "HH:mm" : "h:mm a"
        let time = zone == nil ? "—" : formatter.string(from: date)
        let localDate = zone.map { TimeEngine.compactDate(date, timeZoneID: $0) } ?? "Choose destination"
        return Button { chooseCity(selection) } label: {
            if typeSize >= .xxLarge {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role + " · " + name).font(.body).fixedSize(horizontal: false, vertical: true)
                    Text(time).font(.title2.weight(.semibold)).monospacedDigit()
                    Text(localDate).font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(role).font(.subheadline).foregroundStyle(.secondary)
                        Text(name).font(.body.weight(.medium)).lineLimit(2)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(time).font(.title2.weight(.semibold)).monospacedDigit()
                        Text(localDate).font(.subheadline).foregroundStyle(.secondary)
                    }.frame(width: timeColumnWidth, alignment: .trailing)
                }.frame(maxWidth: .infinity, minHeight: 44)
            }
        }.buttonStyle(.plain).accessibilityLabel(role + ", " + name + ", " + time + ", " + localDate).accessibilityHint("Choose a city")
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
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Label("Currency", systemImage: "banknote").font(.headline)
                    Spacer(minLength: 8)
                    fullConverterButton
                }
                fullConverterButton
            }
            HStack(spacing: 8) {
                amountField(.source)
                Button { editingSide = nil; store.swap() } label: {
                    Image(systemName: "arrow.left.arrow.right").frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(.blue).accessibilityLabel("Swap currencies")
                amountField(.target)
            }
            if !editing {
                Text("Estimate · " + store.detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingSide = nil } }
        }
        .onDisappear { editingSide = nil; editingChanged(false) }
        .onChange(of: editing) { _, value in editingChanged(value) }
        .onChange(of: active) { _, value in if !value { editingSide = nil } }
    }

    private func amountField(_ side: AmountSide) -> some View {
        let code = side == .source ? store.source : store.target
        return VStack(alignment: .leading, spacing: 0) {
            Text(code).font(.footnote.weight(.semibold)).lineLimit(1)
            TextField("Amount", text: Binding(
                get: { store.fieldText(for: side, focused: editingSide == side) },
                set: { store.edit($0, side: side) }
            ))
            .textFieldStyle(.plain).keyboardType(.decimalPad).monospacedDigit()
            .font(.title2.weight(.semibold)).focused($editingSide, equals: side)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityLabel("\(side == .source ? "From" : "To") amount in \(Currency.named(code).name)")
            .accessibilityIdentifier(side == .source ? "home-currency-amount" : "home-currency-target")
        }.padding(.horizontal, 6)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity)
    }

    private var fullConverterButton: some View {
        Button { editingSide = nil; openConverter() } label: {
            Label("Full converter", systemImage: "arrow.up.right").font(.subheadline)
                .frame(minHeight: 44)
        }.buttonStyle(.plain).foregroundStyle(.blue)
            .accessibilityHint("Open all currency conversion tools")
            .accessibilityIdentifier("home-full-converter")
    }
}
