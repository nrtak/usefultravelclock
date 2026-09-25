//  Useful Travel Clock

import SwiftUI

/// Mirrors the web app's clocks screen: city cards + a time scrubber.
struct ClocksView: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.colorScheme) private var scheme

    @State private var now = Date()
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(store.selectedCities) { city in
                    CityRowView(
                        city: city,
                        at: store.displayDate(from: now),
                        homeTimeZoneID: store.homeTimeZoneID,
                        scheme: scheme
                    )
                }
                scrubber
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .onReceive(timer) { now = $0 }
    }

    private var scrubber: some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.scrubHours == 0
                     ? "Right now"
                     : "\(store.scrubHours > 0 ? "+" : "")\(store.scrubHours) hours from now")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Design.mutedForeground(scheme))
                Spacer()
                if store.scrubHours != 0 {
                    Button("Reset") { store.scrubHours = 0 }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
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

/// One city card — white row, phase color only on the analog clock + digital time.
struct CityRowView: View {
    let city: City
    let at: Date
    let homeTimeZoneID: String
    let scheme: ColorScheme

    var body: some View {
        let t = TimeEngine.zonedTime(at, timeZoneID: city.timeZoneID)
        let difference = TimeEngine.timeDifferenceMinutes(at, timeZoneID: city.timeZoneID, homeTimeZoneID: homeTimeZoneID)
        let phase = TimeEngine.dayPhase(t.hourFloat)
        let accent = Design.phase(phase, scheme: scheme)
        let subtitle = [city.region, city.cityState == true ? nil : city.country]
            .compactMap { $0 }.joined(separator: ", ")

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Design.foreground(scheme))
                    .lineLimit(1)
                Text("\(subtitle) · \(TimeEngine.formatDifference(difference))")
                    .font(.system(size: 10))
                    .foregroundStyle(Design.foreground(scheme).opacity(0.8))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                AnalogClockView(hourFloat: t.hourFloat, accent: accent)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(t.hm)
                            .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        Text(t.period)
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.85)
                    }
                    Text(t.date.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.75)
                }
            }
            .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Design.cityRow(scheme))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Design.border(scheme).opacity(0.7)))
                .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 2, y: 1)
        )
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
            let face = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius,
                                             width: radius * 2, height: radius * 2))
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
        .frame(width: 44, height: 44)
    }

    private func point(center c: CGPoint, angleDegrees: Double, distance: Double) -> CGPoint {
        let theta = angleDegrees * .pi / 180
        return CGPoint(x: c.x + distance * sin(theta), y: c.y - distance * cos(theta))
    }
}
