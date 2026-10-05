import SwiftUI
import AVKit

struct TripHelpVideoView: View {
    @State private var player: AVPlayer?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(600.0 / 1068.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Trip Info captioned quick tour")
                } else {
                    ContentUnavailableView("Tour unavailable", systemImage: "play.slash", description: Text("The written guide is available in Help."))
                }
                Text("84-second illustrated worked example. Tap Play to start; pause or replay at any time. Captions are included, with no sound needed. The video is included in the app and works offline.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Choose Los Angeles and Tokyo on Home, then convert USD 100 to JPY. Add coffee and cake prices and subtract a discount. Capture the café menu, review ¥500 and save it with a photo and note. Convert a 10 kg suitcase measurement to pounds. Compare city times and Return to now. Translate “A coffee, please.” from English (General) to Spanish and save it. Fill hotel, flight and transport details, including local time zones and notes. Hold and drag tabs or additional cities, then Done. Check weather update times and set your display preferences. All bookings and weather in the tour are examples.")
                Text("Before traveling offline, refresh rates and weather and download translation languages. Saved values keep their original update times; fresh updates require internet.")
            }.padding()
        }.navigationTitle("How to use Trip Info").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if player == nil, let url = Bundle.main.url(forResource: "Trip_Info_Quick_Tour", withExtension: "mp4") { player = AVPlayer(url: url) }
        }
        .onDisappear { player?.pause() }
    }
}
