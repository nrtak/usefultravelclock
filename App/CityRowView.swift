//  Useful Travel Clock

import SwiftUI

/// Mirrors the web app's clocks screen: city cards + a time scrubber.
struct ClocksView: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.colorScheme) private var scheme

    @State private var adding = false
    @State private var managing: City?
    @State private var now = Date()
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(store.selectedCities) { city in
                    Button { managing = city } label: { CityRowView(
                        city: city,
                        at: store.displayDate(from: now),
                        homeTimeZoneID: store.homeTimeZoneID,
                        scheme: scheme
                    ) }.buttonStyle(.plain)
                }
                Button("+ Add city") { adding = true }.padding(.vertical, 12).disabled(store.cityIDs.count >= UsefulTravelClockStore.maxCities)
                scrubber
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .onReceive(timer) { now = $0 }
        .sheet(isPresented: $adding) { AddCitySheet() }
        .sheet(item: $managing) { CityManagementSheet(city: $0) }
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
        let surface = scheme == .dark ? Design.cityRow(scheme) : (isNight ? Color(red: 0.92, green: 0.90, blue: 0.96) : Color.white)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name).font(.headline)
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
        .overlay(alignment: .bottom) {
            Rectangle().fill(Design.border(scheme)).frame(height: 1)
        }
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
