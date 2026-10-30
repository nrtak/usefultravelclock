import XCTest
import SwiftUI
import UIKit
@testable import UsefulTravelClock

final class HomeLayoutTests: XCTestCase {
    func testCardBudgetIncludesPaddingAndSpacing() {
        XCTAssertEqual(HomeLayout.capacity(height: 183, cardHeight: 160), 0)
        XCTAssertEqual(HomeLayout.capacity(height: 184, cardHeight: 160), 1)
        XCTAssertEqual(HomeLayout.capacity(height: 353, cardHeight: 160), 1)
        XCTAssertEqual(HomeLayout.capacity(height: 354, cardHeight: 160), 2)
        for cardValue in stride(from: 120.0, through: 520.0, by: 20) {
            let cardHeight = CGFloat(cardValue)
            for heightValue in stride(from: 0.0, through: 1000.0, by: 5) {
                let height = CGFloat(heightValue)
                let count = HomeLayout.capacity(height: height, cardHeight: cardHeight)
                if count > 0 {
                    let used = CGFloat(count) * cardHeight + CGFloat(count - 1) * HomeLayout.spacing + 2 * HomeLayout.padding
                    XCTAssertLessThanOrEqual(used, height)
                }
            }
        }
        XCTAssertEqual(HomeLayout.capacity(height: .infinity, cardHeight: 160), 0)
        XCTAssertEqual(HomeLayout.capacity(height: 500, cardHeight: 0), 0)
        XCTAssertEqual(HomeLayout.capacity(height: .greatestFiniteMagnitude, cardHeight: 160), HomeSection.allCases.count)
    }
    func testPreferencesKeepOrderAndDeliberateEmptyHome() {
        XCTAssertEqual(HomeSection.decode("weather,currency,weather,unknown,trip"), [.weather, .currency, .trip])
        XCTAssertEqual(HomeSection.decode(""), [])
        XCTAssertEqual(HomeSection.decode("obsolete"), HomeSection.decode(HomeSection.defaults))
        let chosen: [HomeSection] = [.documents, .clocks, .readiness]
        XCTAssertEqual(HomeSection.decode(HomeSection.encode(chosen)), chosen)
        // A smaller screen must not mutate the user's saved selection.
        XCTAssertEqual(Array(chosen.prefix(HomeLayout.capacity(height: 184, cardHeight: 160))), [.documents])
        XCTAssertEqual(chosen.count, 3)
    }
    @MainActor
    func testHomeHasNoScrollViewAtSmallAndLargeTextSizes() throws {
        let suite = "HomeLayout-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let converter = ConverterStore(preferences: defaults, cacheURL: directory.appendingPathComponent("rates.json"), isOffline: { true })
        for size in [DynamicTypeSize.large, .accessibility3, .accessibility5] {
            for bounds in [CGSize(width: 320, height: 360), CGSize(width: 430, height: 680)] {
                let home = DashboardHome(currency: converter, capacity: .constant(0), active: false, open: { _ in }, chooseCity: { _ in }, openRecord: { _ in }, openDocument: { _ in })
                    .environmentObject(UsefulTravelClockStore(defaults: defaults))
                    .environmentObject(TripStore(directory: directory.appendingPathComponent("trip")))
                    .environmentObject(TripWeatherStore(directory: directory.appendingPathComponent("weather")))
                    .defaultAppStorage(defaults).environment(\.dynamicTypeSize, size)
                let controller = UIHostingController(rootView: home)
                controller.view.frame = CGRect(origin: .zero, size: bounds)
                controller.view.layoutIfNeeded()
                func scrollViews(_ view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews($0) }
                }
                XCTAssertTrue(scrollViews(controller.view).isEmpty, "Home must stay on one screen at \(bounds) / \(size)")
            }
        }
    }
}
