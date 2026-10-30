import SwiftUI

struct DashboardHome: View {
    @ObservedObject var currency: ConverterStore
    @EnvironmentObject private var clock: UsefulTravelClockStore
    @EnvironmentObject private var trip: TripStore
    @AppStorage("trip-home-sections") private var savedSections = HomeSection.defaults
    @AppStorage("travel-destination") private var destinationID = "tyo"
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 160
    @Binding var capacity: Int
    let active: Bool
    let open: (HomeSection) -> Void
    let chooseCity: (String) -> Void
    let openRecord: (TravelRecord) -> Void
    let openDocument: (TripDocument) -> Void
    private var destination: City? { clock.allCities.first { $0.id == destinationID } }
    var body: some View {
        GeometryReader { geometry in
            let slots = HomeLayout.capacity(height: geometry.size.height, cardHeight: cardHeight)
            let sections = HomeSection.decode(savedSections)
            VStack(spacing: HomeLayout.spacing) {
                ForEach(Array(sections.prefix(slots))) { section in
                    ViewThatFits(in: .vertical) {
                        detail(section).fixedSize(horizontal: false, vertical: true)
                        Button { open(section) } label: {
                            Label(section.title, systemImage: section.symbol).font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                    .padding(12).frame(maxWidth: .infinity).frame(height: cardHeight)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                if sections.isEmpty || slots == 0 {
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
        }.navigationBarTitleDisplayMode(.inline)
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
            Button { open(section) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    heading(section)
                    Text("\(currency.fieldText(for: .source, focused: false)) \(currency.source) → \(currency.result(for: currency.target)) \(currency.target)")
                        .font(.title3.weight(.semibold)).monospacedDigit().lineLimit(2)
                    Text("Estimate · " + currency.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    TripRateStatus(store: currency).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).accessibilityHint("Edit amounts and currencies")
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
                            Text(next.timingLabel(at: context.date) + " · " + next.timeLabel(start: next.start > context.date)).font(.caption).lineLimit(2).foregroundStyle(.secondary)
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
                        Text("Stored on your iPhone").font(.caption).foregroundStyle(.secondary)
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
        HStack { Label(section.title, systemImage: section.symbol).font(.headline); Spacer(minLength: 4); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
    }
    private func clockRow(role: String, name: String, zone: String?, date: Date, selection: String) -> some View {
        let formatter = DateFormatter()
        formatter.timeZone = zone.flatMap(TimeZone.init(identifier:))
        formatter.dateFormat = clock.use24 ? "HH:mm" : "h:mm a"
        let time = zone == nil ? "—" : formatter.string(from: date)
        let localDate = zone.map { TimeEngine.compactDate(date, timeZoneID: $0) } ?? "Choose destination"
        return Button { chooseCity(selection) } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) { Text(role).font(.caption).foregroundStyle(.secondary); Text(name).font(.subheadline).lineLimit(1) }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(time).font(.title3.weight(.semibold)).monospacedDigit()
                        Text(localDate).font(.caption2).foregroundStyle(.secondary)
                    }
                }.fixedSize(horizontal: true, vertical: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(role + " · " + name).font(.caption).lineLimit(1)
                    Text(time).font(.title3.weight(.semibold)).monospacedDigit()
                    Text(localDate).font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.buttonStyle(.plain).accessibilityLabel(role + ", " + name + ", " + time + ", " + localDate).accessibilityHint("Choose a city")
    }
}
