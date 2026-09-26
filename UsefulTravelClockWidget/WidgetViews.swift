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
            if let city = entry.cities(upTo: 1).first {
                let t = TimeEngine.zonedTime(entry.date, timeZoneID: city.timeZoneID)
                let difference = TimeEngine.timeDifferenceMinutes(entry.date, timeZoneID: city.timeZoneID, homeTimeZoneID: entry.homeZone)
                let phase = TimeEngine.dayPhase(t.hourFloat)
                let accent = Design.phase(phase, scheme: .light)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(city.shortLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Design.widgetLabel)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        WidgetAnalogClock(hourFloat: t.hourFloat, accent: accent)
                            .frame(width: 40, height: 40)
                    }
                    (Text(t.hm).font(.system(size: 26, weight: .bold).monospacedDigit())
                        + Text(" " + t.period.uppercased()).font(.system(size: 12, weight: .semibold)))
                        .foregroundStyle(Design.widgetLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(TimeEngine.compactDate(entry.date, timeZoneID: city.timeZoneID))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Design.widgetLabel)
                    Text(TimeEngine.formatDifferenceCompact(difference))
                        .font(.system(size: 10))
                        .foregroundStyle(Design.widgetSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text("Pick cities in Useful Travel Clock")
                    .font(.caption)
            }
        }
        .padding(2)
        .widgetBackground(Design.widgetCard)
    }
}

// MARK: - Medium widget (3 × 2 grid)

struct MediumWidgetView: View {
    let entry: UsefulTravelClockEntry

    var body: some View {
        let cities = entry.cities(upTo: 6)
        Group {
            if cities.isEmpty {
                Text("Pick cities in Useful Travel Clock").font(.caption)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 8) {
                    ForEach(cities) { city in
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

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                WidgetAnalogClock(hourFloat: t.hourFloat, accent: accent)
                    .frame(width: 24, height: 24)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(t.hm).font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    Text(t.period).font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Text(city.shortLabel)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.widgetLabel)
                .lineLimit(1)
            Text(TimeEngine.compactDate(entry.date, timeZoneID: city.timeZoneID))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Design.widgetSecondary)
            Text(TimeEngine.formatDifferenceCompact(difference))
                .font(.system(size: 8))
                .foregroundStyle(Design.widgetSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
