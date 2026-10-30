import XCTest
@testable import UsefulTravelClock

final class CameraLifecycleTests: XCTestCase {
    func testCameraStopsWhenPausedHiddenOrInactiveEvenDuringCapture() {
        XCTAssertTrue(TripCameraActivity.shouldRun(visible: true, active: true, recognizing: true, pendingCapture: false))
        XCTAssertFalse(TripCameraActivity.shouldRun(visible: true, active: true, recognizing: false, pendingCapture: false))
        XCTAssertFalse(TripCameraActivity.shouldRun(visible: false, active: true, recognizing: true, pendingCapture: true))
        XCTAssertFalse(TripCameraActivity.shouldRun(visible: true, active: false, recognizing: true, pendingCapture: true))
        XCTAssertTrue(TripCameraActivity.shouldRun(visible: true, active: true, recognizing: false, pendingCapture: true))
        XCTAssertFalse(TripCameraActivity.shouldRun(visible: true, active: true, recognizing: true, pendingCapture: false, covered: true))
        XCTAssertFalse(TripCameraActivity.shouldRun(visible: true, active: true, recognizing: false, pendingCapture: true, covered: true))
    }
    func testRefreshStampExpiresAndRejectsFutureDates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(TripRefreshFreshness.remaining(success: nil, now: now), 0)
        XCTAssertEqual(TripRefreshFreshness.remaining(success: now, now: now), 8)
        XCTAssertEqual(TripRefreshFreshness.remaining(success: now.addingTimeInterval(-3), now: now), 5)
        XCTAssertEqual(TripRefreshFreshness.remaining(success: now.addingTimeInterval(-8), now: now), 0)
        XCTAssertEqual(TripRefreshFreshness.remaining(success: now.addingTimeInterval(1), now: now), 0)
    }
}
