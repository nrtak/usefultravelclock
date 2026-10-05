import XCTest
import AVFoundation
@testable import UsefulTravelClock

final class HelpTourTests: XCTestCase {
    func testChapterTimesFitTheSilentBundledVideo() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Trip_Info_Quick_Tour", withExtension: "mp4"))
        let asset = AVURLAsset(url: url)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertTrue(audio.isEmpty, "The tutorial must contain no sound track")
        let duration = try await asset.load(.duration)
        XCTAssertEqual(CMTimeGetSeconds(duration), 90, accuracy: 0.1)
        XCTAssertEqual(TripHelpChapter.all.map(\.id), Array(0..<15))
        XCTAssertTrue(TripHelpChapter.all.allSatisfy { $0.seconds >= 0 && $0.seconds < CMTimeGetSeconds(duration) })
        XCTAssertEqual(TripHelpChapter.all[4].title, "Open a saved entry")
    }
}
