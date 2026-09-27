//  Useful Travel Clock

import SwiftUI
import UniformTypeIdentifiers

/// Mirrors the web app's clocks screen: city cards + a time scrubber.
struct ClocksView: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.colorScheme) private var scheme

    @State private var adding = false
    @State private var managing: City?
    @State private var now = Date()
    private var editing: Bool { store.isEditingCities }
    @State private var draggedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
            VStack(spacing: 0) {
                let ordered = store.orderedCities(at: now)
                let pinned = ordered.filter { store.favoriteIDs.contains($0.id) }
                let other = ordered.filter { !store.favoriteIDs.contains($0.id) }
                if !pinned.isEmpty {
                    sectionHeading("Pinned", symbol: "pin.fill")
                    ForEach(pinned) { city in editableRow(city) }
                    if !other.isEmpty { sectionHeading("Other cities", symbol: "globe") }
                }
                ForEach(other) { city in editableRow(city) }

            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Button("+ Add city") { adding = true }.padding(.top, 8)
                    .disabled(store.cityIDs.count >= UsefulTravelClockStore.maxCities)
                scrubber
            }.padding(.horizontal, 16).padding(.bottom, 8).background(Design.background(scheme))
        }
        .onReceive(timer) { now = $0 }
        .sheet(isPresented: $adding) { AddCitySheet() }
        .sheet(item: $managing) { CityManagementSheet(city: $0) }
    }

    private func sectionHeading(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8).padding(.vertical, 10)
            .background(Design.secondary(scheme))
            .accessibilityAddTraits(.isHeader)
    }

    private func editableRow(_ city: City) -> some View {
        HStack(spacing: 0) {
            if editing {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.nicknames[city.id]?.isEmpty == false ? store.nicknames[city.id]! : city.name)
                        .font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    if store.nicknames[city.id]?.isEmpty == false { Text(city.name).font(.caption) }
                    let time = TimeEngine.zonedTime(store.displayDate(from: now), timeZoneID: city.timeZoneID)
                    Text(store.use24 ? String(format: "%02d:%02d", time.hour24, time.minute) : time.hm + " " + time.period.uppercased())
                        .font(.title3.weight(.semibold).monospacedDigit())
                    if store.favoriteIDs.contains(city.id) { Label("Pinned", systemImage: "pin.fill").font(.caption.weight(.semibold)) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                Button("Remove", role: .destructive) { store.removeCity(city.id) }
                    .font(.subheadline.weight(.semibold)).frame(width: 68).frame(maxHeight: .infinity)
                    .background(Color.red.opacity(0.10)).accessibilityLabel("Remove \(city.name)")
                Button("Personalize") { managing = city }
                    .font(.subheadline.weight(.semibold)).frame(width: 100).frame(maxHeight: .infinity)
                    .background(Color.blue.opacity(0.12)).accessibilityLabel("Personalize \(city.name)")
            } else {
                CityRowView(city: city, at: store.displayDate(from: now), homeTimeZoneID: store.homeTimeZoneID, scheme: scheme)
                    .onTapGesture { managing = city }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(Rectangle())
        .onLongPressGesture { store.isEditingCities = true }
        .accessibilityAction(named: "Edit cities") { store.isEditingCities = true }
        .modifier(CityWiggle(active: editing && !reduceMotion))
        .onDrag {
            store.isEditingCities = true; draggedID = city.id
            return NSItemProvider(object: city.id as NSString)
        }
        .onDrop(of: [UTType.text], delegate: CityReorderDrop(cityID: city.id, store: store, draggedID: $draggedID))
        .overlay(alignment: .bottom) { Rectangle().fill(Design.border(scheme)).frame(height: 1).padding(.horizontal, 10) }
    }

    private var scrubber: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.scrubHours == 0
                     ? "Right now"
                     : "\(store.scrubHours > 0 ? "+" : "")\(store.scrubHours) hours from now")
                    .font(.subheadline.weight(.semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Design.mutedForeground(scheme))
                Spacer()
                Group {
                    Button("Reset to now") { store.scrubHours = 0; now = Date() }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Design.secondary(scheme)))
                        .foregroundStyle(Design.foreground(scheme))
                }
            }
            Slider(
                value: Binding(
                    get: { Double(store.scrubHours) },
                    set: { store.scrubHours = Int($0.rounded()) }
                ),
                in: -24...24,
                step: 1
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Design.background(scheme).opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Design.border(scheme)))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
        .padding(.top, 8)
    }
}

private struct CityWiggle: ViewModifier {
    let active: Bool
    @State private var tilted = false
    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(active ? (tilted ? 0.45 : -0.45) : 0))
            .onChange(of: active) { enabled in
                if enabled { withAnimation(.easeInOut(duration: 0.16).repeatForever(autoreverses: true)) { tilted = true } }
                else { tilted = false }
            }
    }
}

@MainActor private struct CityReorderDrop: DropDelegate {
    let cityID: String
    let store: UsefulTravelClockStore
    @Binding var draggedID: String?
    func dropEntered(info: DropInfo) {
        guard let source = draggedID, source != cityID else { return }
        withAnimation { store.moveCity(source, to: cityID) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { draggedID = nil; return true }
}

/// Readable city card with full location, difference, and date.
struct CityRowView: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    let city: City
    let at: Date
    let homeTimeZoneID: String
    let scheme: ColorScheme

    var body: some View {
        let t = TimeEngine.zonedTime(at, timeZoneID: city.timeZoneID)
        let difference = TimeEngine.timeDifferenceMinutes(at, timeZoneID: city.timeZoneID, homeTimeZoneID: homeTimeZoneID)
        let phase = TimeEngine.dayPhase(t.hourFloat)
        let subtitle = [city.region, city.cityState == true ? nil : city.country]
            .compactMap { $0 }.joined(separator: ", ")

        let isNight = phase == .dusk || phase == .evening || phase == .night
        let ink = scheme == .dark ? Color.white : Color(red: 0.16, green: 0.20, blue: 0.30)
        let surface = Design.phaseSurface(phase, scheme: scheme)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    if let name = store.nicknames[city.id], !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(name).font(.headline)
                        Text(city.name).font(.subheadline)
                    } else { Text(city.name).font(.headline) }
                    if store.favoriteIDs.contains(city.id) { Label("Pinned", systemImage: "pin.fill").font(.caption.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 3).background(Color.blue.opacity(0.15), in: Capsule()) }
                    Text(subtitle).font(.subheadline)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    if store.showAnalog { AnalogClockView(hourFloat: t.hourFloat, accent: ink) }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(store.use24 ? String(format: "%02d:%02d", t.hour24, t.minute) : t.hm)
                            .font(.system(size: 30, weight: .bold).monospacedDigit())
                        if !store.use24 {
                            Text(t.period.uppercased()).font(.subheadline.weight(.semibold))
                        }
                    }.fixedSize()
                }
                .offset(y: (store.showDate || store.showWeekday || store.showDifference) ? 10 : 0)
            }
            if store.showDate || store.showWeekday || store.showDifference {
                HStack(spacing: 8) {
                    if store.showDate || store.showWeekday { Text(compactDate) }
                    if store.showDifference {
                        Text(TimeEngine.formatDifferenceCompact(difference))
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 8)
        .padding(.vertical, store.cityIDs.count <= 4 ? 12 : store.cityIDs.count <= 6 ? 9 : 6)
        .frame(maxWidth: .infinity)
        .background(surface)
        .contentShape(Rectangle())
    }

    private var compactDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: city.timeZoneID)
        formatter.dateFormat = store.showDate
            ? (store.showWeekday ? "EEE, MMM d" : "MMM d")
            : (store.showWeekday ? "EEE" : "")
        return formatter.string(from: at)
    }
}

/// Detailed analog clock matching the web app's SVG:
/// circle, 12 ticks (major at 12/3/6/9), distinct hour & minute hands, center pin.
struct AnalogClockView: View {
    let hourFloat: Double
    var accent: Color

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 44
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = 20 * scale

            // Face
            let face = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
            context.fill(face, with: .color(accent.opacity(0.1)))
            context.stroke(face, with: .color(accent.opacity(0.45)), lineWidth: scale)

            // Ticks
            for index in 0..<12 {
                let major = index % 3 == 0
                let inner = (major ? 8.0 : 7.5) * scale
                let outer = (major ? 5.0 : 6.0) * scale
                var line = Path()
                line.move(to: point(center: c, angleDegrees: Double(index) * 30, distance: radius - inner))
                line.addLine(to: point(center: c, angleDegrees: Double(index) * 30, distance: radius - outer))
                context.stroke(
                    line,
                    with: .color(accent.opacity(major ? 0.8 : 0.5)),
                    style: StrokeStyle(lineWidth: (major ? 1.5 : 1) * scale, lineCap: .round)
                )
            }

            // Hour hand
            let hourAngle = (hourFloat.truncatingRemainder(dividingBy: 12)) * 30
            var hour = Path()
            hour.move(to: c)
            hour.addLine(to: point(center: c, angleDegrees: hourAngle, distance: 10.5 * scale))
            context.stroke(hour, with: .color(accent), style: StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round))

            // Minute hand
            let minuteAngle = (hourFloat.truncatingRemainder(dividingBy: 1)) * 360
            var minute = Path()
            minute.move(to: point(center: c, angleDegrees: minuteAngle + 180, distance: 2 * scale))
            minute.addLine(to: point(center: c, angleDegrees: minuteAngle, distance: 14.5 * scale))
            context.stroke(minute, with: .color(accent.opacity(0.9)), style: StrokeStyle(lineWidth: 1.4 * scale, lineCap: .round))

            // Center pin
            context.fill(Path(ellipseIn: CGRect(x: c.x - 2 * scale, y: c.y - 2 * scale, width: 4 * scale, height: 4 * scale)), with: .color(accent))
        }
        .frame(width: 64, height: 64)
    }

    private func point(center c: CGPoint, angleDegrees: Double, distance: Double) -> CGPoint {
        let theta = angleDegrees * .pi / 180
        return CGPoint(x: c.x + distance * sin(theta), y: c.y - distance * cos(theta))
    }
}
