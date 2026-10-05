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
                Text("32-second illustrated tour. Tap Play to start; pause or replay at any time. Captions are included, with no sound needed. The video is included in the app and works offline.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Choose cities on Home and edit either amount. Choose Camera or Photo and review readings before saving. In World Time, move the comparison slider and Return to now. Choose translation languages and save notes. Hold and drag tabs or additional cities, then tap Done.")
                Text("Before traveling offline, refresh rates and weather and download translation languages. Saved values keep their original update times; fresh updates require internet.")
            }.padding()
        }.navigationTitle("How to use Trip Info").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if player == nil, let url = Bundle.main.url(forResource: "Trip_Info_Quick_Tour", withExtension: "mp4") { player = AVPlayer(url: url) }
        }
        .onDisappear { player?.pause() }
    }
}
