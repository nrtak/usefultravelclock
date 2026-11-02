import SwiftUI

// Static accents give content depth without running animations or changing layout.
struct TripCardBackground: View {
    var accent: Color = .blue
    var cornerRadius: CGFloat = 22
    var surface: Color = Color(.secondarySystemBackground)
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape.fill(surface)
            .overlay {
                shape.fill(LinearGradient(colors: [accent.opacity(scheme == .dark ? 0.16 : 0.09), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay {
                shape.strokeBorder(contrast == .increased ? Color.primary.opacity(0.45) : accent.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 6, y: 3)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct TripFeatureIcon: View {
    let symbol: String
    var color: Color = .blue
    var size: CGFloat = 32
    var body: some View {
        Image(systemName: symbol).font(.system(size: size * 0.48, weight: .semibold))
            .symbolRenderingMode(.hierarchical).foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension ToolbarContent {
    @ToolbarContentBuilder
    func tripToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            // Let the system group and draw its native glass toolbar controls.
            self.sharedBackgroundVisibility(.automatic)
        } else {
            self
        }
    }
}

private struct TripLegacyButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).frame(minWidth: 44, minHeight: 44)
            .foregroundStyle(enabled ? (primary ? Color.white : Color.blue) : Color.secondary)
            .background(enabled && primary ? Color.blue : Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(enabled ? (primary ? Color.clear : Color.blue.opacity(0.45)) : Color.secondary.opacity(0.25)))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct TripSectionLabel: View {
    let title: String
    let symbol: String
    var color: Color = .blue
    var body: some View {
        Label { Text(title) } icon: {
            TripFeatureIcon(symbol: symbol, color: color, size: 28)
        }.font(.headline)
    }
}

extension View {
    // Used only for actions. Information cards retain their opaque surfaces.
    @ViewBuilder
    func tripButtonStyle(primary: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if primary {
                self.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
            } else {
                self.buttonStyle(.glass).buttonBorderShape(.capsule)
            }
        } else {
            self.buttonStyle(TripLegacyButtonStyle(primary: primary))
        }
    }

    @ViewBuilder
    func tripToolbarButtonStyle(primary: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            // Toolbar buttons already get glass; don't layer another effect.
            self.buttonStyle(.automatic)
        } else {
            self.buttonStyle(TripLegacyButtonStyle(primary: primary))
        }
    }

    @ViewBuilder
    func tripNavigationAppearance() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.never)
                .toolbarBackground(.automatic, for: .tabBar)
        } else {
            self
        }
    }

    func tripPanel(accent: Color = .blue) -> some View {
        padding(12).background {
            TripCardBackground(accent: accent, cornerRadius: 18, surface: Color(.systemBackground))
        }
    }
}
struct TripArtwork: View {
    let symbol: String
    var body: some View {
        HStack(spacing: 18) {
            Rectangle().frame(height: 1)
            ZStack {
                Image(systemName: symbol).font(.system(size: 35, weight: .ultraLight)).rotationEffect(.degrees(-8))
                Image(systemName: "airplane").font(.system(size: 17, weight: .ultraLight)).foregroundStyle(Color.orange.opacity(0.65)).offset(x: -37, y: -15)
                Image(systemName: "mappin").font(.system(size: 17, weight: .ultraLight)).foregroundStyle(Color.teal.opacity(0.65)).offset(x: 38, y: 16)
            }.frame(width: 110, height: 60)
            Rectangle().frame(height: 1)
        }.foregroundStyle(Color.blue.opacity(0.45)).accessibilityHidden(true)
    }
}
struct TripAnalogClock: View {
    let date: Date
    let zone: String
    var size: CGFloat = 54
    var body: some View {
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: zone) ?? .gmt
        let components = calendar.dateComponents(in: timeZone, from: date)
        let minute = Double(components.minute ?? 0)
        let hour = Double((components.hour ?? 0) % 12)
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 1)
            ForEach(0..<4) { mark in
                Capsule().frame(width: 1, height: max(2, size / 18)).offset(y: -size * 0.42)
                    .rotationEffect(.degrees(Double(mark) * 90)).foregroundStyle(.secondary)
            }
            Capsule().frame(width: max(1.5, size / 27), height: size * 16 / 54).offset(y: -size * 8 / 54).rotationEffect(.degrees(hour * 30 + minute / 2))
            Capsule().frame(width: max(1, size / 36), height: size * 23 / 54).offset(y: -size * 11.5 / 54).rotationEffect(.degrees(minute * 6))
            Circle().frame(width: max(3, size * 4 / 54), height: max(3, size * 4 / 54))
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct TripActionButton: View {
    let title: String
    let primary: Bool
    let action: () -> Void
    init(_ title: String, primary: Bool, action: @escaping () -> Void) {
        self.title = title; self.primary = primary; self.action = action
    }
    var body: some View {
        if primary {
            Button(action: action) { HStack(spacing: 6) { Image(systemName: "checkmark"); Text(title).fontWeight(.semibold) }.fixedSize(horizontal: true, vertical: false) }
                .tripToolbarButtonStyle(primary: true)
        } else {
            Button(action: action) { HStack(spacing: 6) { Image(systemName: "xmark"); Text(title) }.fixedSize(horizontal: true, vertical: false) }
                .tripToolbarButtonStyle()
        }
    }
}

struct TripNavigationButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: title == "Back" ? "arrow.left" : "checkmark")
                Text(title)
            }.font(.subheadline.weight(.semibold)).fixedSize(horizontal: true, vertical: false)
                .frame(minHeight: 32)
        }.tripToolbarButtonStyle()
    }
}
