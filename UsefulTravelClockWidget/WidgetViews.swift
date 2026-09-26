//  Useful Travel Clock

import SwiftUI
import WidgetKit

// Widget visuals follow the approved mockups: white card, phase color only on
// the analog clock and digital time, abbreviated days, "+x hrs" differences,
// "UK"-style country abbreviations, full day+date so no mental math is needed.

// MARK: - Small widget

struct SmallWidgetView: View {
    let entry: UsefulTravelClockEntry

    var body: some View {
        Group {
            if entry.cities(upTo: 2).count == 2 {
                VStack(spacing: 4) {
                    ForEach(Array(entry.cities(upTo: 2).enumerated()), id: \.offset) { index, city in
                        if index > 0 { Divider() }
                        SmallTwoCityCell(city: city, entry: entry)
                    }
                }.frame(maxHeight: .infinity)
            } else if let city = entry.cities(upTo: 1).first {
                let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
                let difference = TimeEngine.timeDifferenceMinutes(entry.date, timeZoneID: city.timeZoneID, homeTimeZoneID: entry.homeZone)
                let phase = TimeEngine.dayPhase(t.hourFloat)
                let accent = Design.phase(phase, scheme: .light)

                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Design.widgetLabel)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    WidgetAnalogClock(hourFloat: t.hourFloat, accent: Design.phase(.night, scheme: .light))
                        .frame(width: 56, height: 56)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer(minLength: 0)
                    (Text(widgetTime(t)).font(.system(size: 28, weight: .bold).monospacedDigit())
                        + Text(widgetPeriod(t)).font(.system(size: 12, weight: .semibold)))
                        .foregroundStyle(Design.widgetLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(TimeEngine.compactDate(entry.date, timeZoneID: city.timeZoneID)) · \(TimeEngine.formatDifferenceCompact(difference))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Design.widgetLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text("Pick cities in Useful Travel Clock")
                    .font(.caption)
            }
        }
        .padding(2)
        .widgetBackground(widgetSurface(entry))
    }
}

// MARK: - Medium widget (3 × 2 grid)

struct MediumWidgetView: View {
    let entry: UsefulTravelClockEntry

    var body: some View {
        let cities = entry.cities(upTo: 6)
        let columns = cities.count == 2 || cities.count == 4 ? 2 : 3
        Group {
            if cities.isEmpty {
                Text("Pick cities in Useful Travel Clock").font(.caption)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                    ForEach(Array(cities.enumerated()), id: \.offset) { _, city in
                        gridCell(city: city)
                    }
                }
            }
        }
        .widgetBackground(Design.widgetCard)
    }

    private func gridCell(city: City) -> some View {
        let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
        let difference = TimeEngine.timeDifferenceMinutes(entry.date, timeZoneID: city.timeZoneID, homeTimeZoneID: entry.homeZone)
        let phase = TimeEngine.dayPhase(t.hourFloat)
        let accent = Design.phase(phase, scheme: .light)
        let count = entry.cityIDs.count
        let roomy = count <= 3
        let timeSize: CGFloat = count == 2 ? 28 : count <= 4 ? 23 : 20

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                WidgetAnalogClock(hourFloat: t.hourFloat, accent: Design.widgetLabel)
                    .frame(width: roomy ? 30 : 20, height: roomy ? 30 : 20)
                (Text(widgetTime(t)).font(.system(size: timeSize, weight: .bold).monospacedDigit())
                    + Text(widgetPeriod(t)).font(.system(size: count <= 4 ? 11 : 9, weight: .semibold)))
                    .foregroundStyle(Design.widgetLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Text(city.name)
                .font(.system(size: roomy ? 16 : 13, weight: .semibold))
                .foregroundStyle(Design.widgetLabel)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            Text("\(TimeEngine.compactDate(entry.date, timeZoneID: city.timeZoneID)) · \(TimeEngine.formatDifferenceCompact(difference))")
                .font(.system(size: count == 2 ? 12 : 10, weight: .medium))
                .foregroundStyle(Design.widgetLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, roomy ? 8 : 2)
        .background(Design.phaseSurface(phase, scheme: .light), in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct SmallTwoCityCell: View {
    let city: City
    let entry: UsefulTravelClockEntry
    var body: some View {
        let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
        let difference = TimeEngine.timeDifferenceMinutes(entry.date, timeZoneID: city.timeZoneID, homeTimeZoneID: entry.homeZone)
        VStack(alignment: .leading, spacing: 1) {
            Text(city.name).font(.system(size: 13, weight: .semibold))
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                WidgetAnalogClock(hourFloat: t.hourFloat, accent: Design.widgetLabel).frame(width: 26, height: 26)
                (Text(widgetTime(t)).font(.system(size: 24, weight: .bold).monospacedDigit())
                 + Text(widgetPeriod(t)).font(.system(size: 10, weight: .semibold)))
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            Text("\(TimeEngine.compactDate(entry.date, timeZoneID: city.timeZoneID)) · \(TimeEngine.formatDifferenceCompact(difference))")
                .font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(Design.widgetLabel)
            .background(Design.phaseSurface(TimeEngine.dayPhase(t.hourFloat), scheme: .light))
    }
}

private func widgetSurface(_ entry: UsefulTravelClockEntry) -> Color {
    guard entry.cityIDs.count == 1, let city = entry.cities(upTo: 1).first else { return .white }
    return Design.phaseSurface(TimeEngine.dayPhase(TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID).hourFloat), scheme: .light)
}

private func widgetTime(_ time: ZonedTime) -> String {
    UserDefaults.usefultravelclockShared.bool(forKey: "use24") ? String(format: "%02d:%02d", time.hour24, time.minute) : time.hm
}

private func widgetPeriod(_ time: ZonedTime) -> String {
    UserDefaults.usefultravelclockShared.bool(forKey: "use24") ? "" : " " + time.period.uppercased()
}

// MARK: - Lock screen widgets

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsefulTravelClockEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    private var city: City? { entry.cities(upTo: 1).first }

    private var circular: some View {
        Group {
            if let city {
                let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
                WidgetAnalogClock(hourFloat: t.hourFloat, accent: .white)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "clock")
            }
        }
    }

    private var rectangular: some View {
        Group {
            if let city {
                let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
                let difference = TimeEngine.timeDifferenceMinutes(entry.date, timeZoneID: city.timeZoneID, homeTimeZoneID: entry.homeZone)
                VStack(alignment: .leading, spacing: 1) {
                    Text(city.shortLabel)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(t.hm).font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        Text(t.period).font(.system(size: 11, weight: .semibold))
                    }
                    Text("\(TimeEngine.compactDate(entry.date, timeZoneID: city.timeZoneID)) · \(TimeEngine.formatDifferenceCompact(difference))")
                        .font(.system(size: 10))
                        .opacity(0.85)
                        .lineLimit(1)
                }
            } else {
                Text("Pick cities in Useful Travel Clock").font(.caption2)
            }
        }
    }

    private var inline: some View {
        Group {
            if let city {
                let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
                Text("\(city.shortLabel) \(t.hm) \(t.period)")
            } else {
                Text("Pick cities in Useful Travel Clock")
            }
        }
    }
}

// MARK: - Analog clock for widgets

struct WidgetAnalogClock: View {
    let hourFloat: Double
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 44
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = 20 * scale

            let face = Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2))
            context.fill(face, with: .color(accent.opacity(0.1)))
            context.stroke(face, with: .color(accent.opacity(0.45)), lineWidth: scale)

            for index in 0..<12 {
                let major = index % 3 == 0
                let inner = (major ? 8.0 : 7.5) * scale
                let outer = (major ? 5.0 : 6.0) * scale
                var line = Path()
                line.move(to: Self.point(center: c, angleDegrees: Double(index) * 30, distance: radius - inner))
                line.addLine(to: Self.point(center: c, angleDegrees: Double(index) * 30, distance: radius - outer))
                context.stroke(line, with: .color(accent.opacity(major ? 0.8 : 0.5)),
                               style: StrokeStyle(lineWidth: (major ? 1.5 : 1) * scale, lineCap: .round))
            }

            let hourAngle = (hourFloat.truncatingRemainder(dividingBy: 12)) * 30
            var hour = Path()
            hour.move(to: c)
            hour.addLine(to: Self.point(center: c, angleDegrees: hourAngle, distance: 10.5 * scale))
            context.stroke(hour, with: .color(accent), style: StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round))

            let minuteAngle = (hourFloat.truncatingRemainder(dividingBy: 1)) * 360
            var minute = Path()
            minute.move(to: Self.point(center: c, angleDegrees: minuteAngle + 180, distance: 2 * scale))
            minute.addLine(to: Self.point(center: c, angleDegrees: minuteAngle, distance: 14.5 * scale))
            context.stroke(minute, with: .color(accent.opacity(0.9)), style: StrokeStyle(lineWidth: 1.4 * scale, lineCap: .round))

            context.fill(Path(ellipseIn: CGRect(x: c.x - 2 * scale, y: c.y - 2 * scale, width: 4 * scale, height: 4 * scale)), with: .color(accent))
        }
    }

    private static func point(center c: CGPoint, angleDegrees: Double, distance: Double) -> CGPoint {
        let theta = angleDegrees * .pi / 180
        return CGPoint(x: c.x + distance * sin(theta), y: c.y - distance * cos(theta))
    }
}

// MARK: - iOS 17+ container background compatibility

extension View {
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { color }
        } else {
            background(color)
        }
    }
}
