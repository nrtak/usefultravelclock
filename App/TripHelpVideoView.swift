import SwiftUI
import AVKit

struct TripHelpChapter: Identifiable {
    let id: Int
    let title: String
    let summary: String
    var seconds: Double { Double(id * 6) }
    static let all: [TripHelpChapter] = [
        .init(id: 0, title: "Home", summary: "Choose Los Angeles and Tokyo; convert USD 100 to JPY."),
        .init(id: 1, title: "Multiple prices", summary: "Add ¥500 and ¥650, subtract ¥100, then Use total."),
        .init(id: 2, title: "Camera & photos", summary: "Capture the café menu and review the ¥500 price."),
        .init(id: 3, title: "Save a conversion", summary: "Keep the photo and add ‘Coffee at the station café’, then Save."),
        .init(id: 4, title: "Open a saved entry", summary: "Open Saved and check your conversion’s photo, note and original rate date."),
        .init(id: 5, title: "Units", summary: "Read a 10 kg suitcase measurement, convert to pounds, add a note and Save conversion."),
        .init(id: 6, title: "World Time", summary: "Compare all clocks, then Return to now."),
        .init(id: 7, title: "Translate", summary: "Translate ‘A coffee, please.’ from English (General) to Spanish; review, add a note and Save."),
        .init(id: 8, title: "Hotel", summary: "Fill hotel name, booking, address, local check-in/out times and notes, then Save."),
        .init(id: 9, title: "Flight", summary: "Fill operator, flight number, route, local departure/arrival times and notes, then Save."),
        .init(id: 10, title: "Transport", summary: "Fill a train or bus journey, booking, local times and notes, then Save."),
        .init(id: 11, title: "Reorder cities & tabs", summary: "Hold and drag, then Done. Your chosen order is remembered."),
        .init(id: 12, title: "Weather", summary: "Choose a city and Refresh; check observation, retrieval and forecast times."),
        .init(id: 13, title: "Settings", summary: "Choose appearance, clock options and optional app lock."),
        .init(id: 14, title: "Offline preparation", summary: "Refresh rates/weather and download translation languages before traveling.")
    ]
}

struct TripHelpVideoView: View {
    @State private var player: AVPlayer?
    @State private var selectedChapter: Int?
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let player {
                        VideoPlayer(player: player)
                            .aspectRatio(600.0 / 1068.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Silent Trip Info tutorial, with visual captions")
                            .id("tour-player")
                    } else {
                        ContentUnavailableView("Tour unavailable", systemImage: "play.slash", description: Text("Read the written chapter steps below."))
                    }
                    Text("90-second illustrated worked example. Silent, with captions and a hand cursor. Tap Play, pause or replay at any time. Included in the app for offline use; sample bookings and weather are illustrative.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Jump to a chapter").font(.headline).accessibilityAddTraits(.isHeader)
                    ForEach(TripHelpChapter.all) { chapter in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                selectedChapter = chapter.id
                                player?.seek(to: CMTime(seconds: chapter.seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                                player?.play()
                                proxy.scrollTo("tour-player", anchor: .top)
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(chapter.title).font(.headline)
                                    Spacer()
                                    Text(String(format: "%d:%02d", chapter.id * 6 / 60, chapter.id * 6 % 60)).font(.caption).monospacedDigit()
                                    if selectedChapter == chapter.id { Image(systemName: "checkmark.circle.fill").accessibilityHidden(true) }
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain).disabled(player == nil)
                                .accessibilityLabel("Play chapter: " + chapter.title)
                                .accessibilityHint("Starts this chapter in the silent video")
                                .accessibilityAddTraits(selectedChapter == chapter.id ? .isSelected : [])
                            Text(chapter.summary).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("The video is an illustrated guide. Use these written steps for the actual control names. Language downloads and fresh rates/weather need internet; saved entries keep their original values and update times.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
        }.navigationTitle("How to use Trip Info").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if player == nil, let url = Bundle.main.url(forResource: "Trip_Info_Quick_Tour", withExtension: "mp4") {
                let local = AVPlayer(url: url)
                local.isMuted = true
                player = local
            }
        }
        .onDisappear { player?.pause() }
    }
}
