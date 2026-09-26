//  Useful Travel Clock

import SwiftUI

/// Design tokens ported from the web app's `src/styles.css` (OKLCH → sRGB).
/// Phase colors are text/clock accents only — never card backgrounds.
enum Design {

    // MARK: Light theme

    static let backgroundLight = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let foregroundLight = Color(red: 0.078, green: 0.082, blue: 0.118)
    static let mutedForegroundLight = Color(red: 0.337, green: 0.353, blue: 0.412)
    static let borderLight = Color(red: 0.702, green: 0.718, blue: 0.765)
    static let secondaryLight = Color(red: 0.871, green: 0.882, blue: 0.918)
    static let primaryLight = Color(red: 0.145, green: 0.157, blue: 0.208)

    // MARK: Dark theme

    static let backgroundDark = Color(red: 0.027, green: 0.027, blue: 0.043)
    static let foregroundDark = Color(red: 0.957, green: 0.961, blue: 0.976)
    static let mutedForegroundDark = Color(red: 0.561, green: 0.569, blue: 0.624)
    static let borderDark = Color.white.opacity(0.10)
    static let secondaryDark = Color(red: 0.098, green: 0.098, blue: 0.141)
    static let primaryDark = Color(red: 0.957, green: 0.961, blue: 0.976)
    static let cityRowDark = Color(red: 0.090, green: 0.090, blue: 0.125)

    static func background(_ scheme: ColorScheme) -> Color { scheme == .dark ? backgroundDark : backgroundLight }
    static func foreground(_ scheme: ColorScheme) -> Color { scheme == .dark ? foregroundDark : foregroundLight }
    static func mutedForeground(_ scheme: ColorScheme) -> Color { scheme == .dark ? mutedForegroundDark : mutedForegroundLight }
    static func border(_ scheme: ColorScheme) -> Color { scheme == .dark ? borderDark : borderLight }
    static func secondary(_ scheme: ColorScheme) -> Color { scheme == .dark ? secondaryDark : secondaryLight }
    static func primary(_ scheme: ColorScheme) -> Color { scheme == .dark ? primaryDark : primaryLight }
    static func cityRow(_ scheme: ColorScheme) -> Color { scheme == .dark ? cityRowDark : backgroundLight }

    // MARK: Phase accents (light values)

    static let phaseDayLight = Color(red: 0.686, green: 0.561, blue: 0.0)
    static let phaseAfternoonLight = Color(red: 0.827, green: 0.424, blue: 0.0)
    static let phaseDuskLight = Color(red: 0.808, green: 0.325, blue: 0.259)
    static let phaseEveningLight = Color(red: 0.196, green: 0.463, blue: 0.694)
    static let phaseNightLight = Color(red: 0.173, green: 0.275, blue: 0.471)

    // MARK: Phase accents (dark values)

    static let phaseDayDark = Color(red: 0.910, green: 0.804, blue: 0.384)
    static let phaseAfternoonDark = Color(red: 0.996, green: 0.675, blue: 0.396)
    static let phaseDuskDark = Color(red: 0.980, green: 0.608, blue: 0.510)
    static let phaseEveningDark = Color(red: 0.463, green: 0.694, blue: 0.890)
    static let phaseNightDark = Color(red: 0.482, green: 0.576, blue: 0.745)

    static func phase(_ phase: DayPhase, scheme: ColorScheme) -> Color {
        switch (phase, scheme) {
        case (.day, .dark): return phaseDayDark
        case (.day, _): return phaseDayLight
        case (.afternoon, .dark): return phaseAfternoonDark
        case (.afternoon, _): return phaseAfternoonLight
        case (.dusk, .dark): return phaseDuskDark
        case (.dusk, _): return phaseDuskLight
        case (.evening, .dark): return phaseEveningDark
        case (.evening, _): return phaseEveningLight
        case (.night, .dark): return phaseNightDark
        case (.night, _): return phaseNightLight
        }
    }

    /// Widgets render on fixed light cards; use the light palette there.
    static let widgetCard = Color.white
    static let widgetLabel = Color(red: 0.20, green: 0.20, blue: 0.23)
    static let widgetSecondary = Color(red: 0.52, green: 0.53, blue: 0.57)
}
