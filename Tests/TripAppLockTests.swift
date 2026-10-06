import XCTest
@testable import UsefulTravelClock

final class TripAppLockTests: XCTestCase {
    @MainActor func testLockStartsDisabledWithoutPreference() {
        let name = "TripAppLockTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let lock = TripAppLock(defaults: defaults)
        XCTAssertFalse(lock.enabled)
        XCTAssertFalse(lock.unlocked)
    }
    @MainActor func testPersistedLockStartsLocked() async {
        let name = "TripAppLockTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "trip-app-lock")
        let lock = TripAppLock(defaults: defaults)
        XCTAssertTrue(lock.enabled)
        XCTAssertFalse(lock.unlocked)
        lock.lock()
        XCTAssertFalse(lock.unlocked)
        XCTAssertFalse(lock.authenticating)
        await lock.setEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: "trip-app-lock"))
    }
}
