import SwiftUI

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
                Image(systemName: "airplane").font(.system(size: 17, weight: .ultraLight)).offset(x: -37, y: -15)
                Image(systemName: "mappin").font(.system(size: 17, weight: .ultraLight)).offset(x: 38, y: 16)
            }.frame(width: 110, height: 60)
            Rectangle().frame(height: 1)
        }.foregroundStyle(Color.blue.opacity(0.3)).accessibilityHidden(true)
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
