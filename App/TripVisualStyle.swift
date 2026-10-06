import SwiftUI

extension ToolbarContent {
    @ToolbarContentBuilder
    func tripToolbarBackground() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}

struct TripButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12).frame(minHeight: 44)
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
            Image(systemName: symbol).foregroundStyle(color)
        }.font(.headline)
    }
}

extension View {
    func tripPanel() -> some View {
        padding(12).background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
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
    var body: some View {
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: zone) ?? .gmt
        let components = calendar.dateComponents(in: timeZone, from: date)
        let minute = Double(components.minute ?? 0)
        let hour = Double((components.hour ?? 0) % 12)
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 1)
            Capsule().frame(width: 2, height: 16).offset(y: -8).rotationEffect(.degrees(hour * 30 + minute / 2))
            Capsule().frame(width: 1.5, height: 23).offset(y: -11.5).rotationEffect(.degrees(minute * 6))
            Circle().frame(width: 4, height: 4)
        }.frame(width: 54, height: 54).accessibilityHidden(true)
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
                .buttonStyle(TripButtonStyle(primary: true))
        } else {
            Button(action: action) { HStack(spacing: 6) { Image(systemName: "xmark"); Text(title) }.fixedSize(horizontal: true, vertical: false) }
                .buttonStyle(TripButtonStyle())
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
        }.buttonStyle(TripButtonStyle())
    }
}
