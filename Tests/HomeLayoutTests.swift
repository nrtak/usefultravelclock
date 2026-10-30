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

    func testSelectionReplacesAVisibleCardEvenWhenHomeIsFull() {
        let changed = HomeSection.selecting(.weather, in: HomeSection.defaults, capacity: 3, replacing: .trip)
        XCTAssertEqual(HomeSection.decode(changed), [.clocks, .currency, .weather])
        XCTAssertEqual(HomeSection.selecting(.weather, in: changed, capacity: 3), changed)
        XCTAssertEqual(HomeSection.decode(HomeSection.selecting(.documents, in: changed, capacity: 4)), [.clocks, .currency, .weather, .documents])
        XCTAssertEqual(HomeSection.selecting(.documents, in: changed, capacity: 3), changed, "A full Home requires an explicit replacement")
        XCTAssertEqual(HomeSection.selecting(.documents, in: changed, capacity: 0), changed)
    }

    func testReplacingWithAHiddenCardKeepsOtherSavedChoicesAndPersistsOrder() throws {
        let suite = "HomeSelection-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let saved = "clocks,currency,trip,weather,documents"
        let changed = HomeSection.selecting(.weather, in: saved, capacity: 2, replacing: .currency)
        XCTAssertEqual(HomeSection.decode(changed), [.clocks, .weather, .trip, .documents])
        defaults.set(changed, forKey: "trip-home-sections")
        XCTAssertEqual(HomeSection.decode(try XCTUnwrap(defaults.string(forKey: "trip-home-sections"))), [.clocks, .weather, .trip, .documents])
        XCTAssertEqual(HomeSection.selecting(.readiness, in: saved, capacity: 2, replacing: .documents), saved, "Replacement must target a visible slot")
        XCTAssertEqual(HomeSection.selecting(.currency, in: "", capacity: 1), "currency")
    }

    @MainActor
    func testHomeCurrencyFieldFitsAndEditsTheSharedConverter() async throws {
        let suite = "HomeCurrency-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let ratesURL = directory.appendingPathComponent("rates.json")
        let rates = RateSnapshot(fetchedAt: Date(), rows: [Rate(date: "2026-10-30", base: "USD", quote: "EUR", rate: Decimal(string: "0.8")!)])
        try JSONEncoder().encode(rates).write(to: ratesURL)
        let converter = ConverterStore(preferences: defaults, cacheURL: ratesURL, isOffline: { true })
        converter.source = "USD"; converter.target = "EUR"
        let home = DashboardHome(currency: converter, savedSections: .constant("currency"), capacity: .constant(0), active: false, open: { _ in }, chooseCity: { _ in }, openRecord: { _ in }, openDocument: { _ in })
            .environmentObject(UsefulTravelClockStore(defaults: defaults))
            .environmentObject(TripStore(directory: directory.appendingPathComponent("trip")))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 500)
        let controller = UIHostingController(rootView: home)
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(400))
        controller.view.layoutIfNeeded()
        func fields(_ view: UIView) -> [UITextField] {
            if let field = view as? UITextField { return [field] }
            return view.subviews.flatMap(fields)
        }
        let inputs = fields(controller.view)
        if inputs.isEmpty {
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.lifetime = .keepAlways; add(attachment)
        }
        let field = try XCTUnwrap(inputs.first, "The compact card must retain an editable amount instead of its fallback title")
        XCTAssertGreaterThan(field.bounds.height, 0)
        field.text = "25"
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(converter.value(for: "EUR"), 20)
        let reopened = ConverterStore(preferences: defaults, cacheURL: ratesURL, isOffline: { true })
        XCTAssertEqual(reopened.value(for: "USD"), 25)
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
                let home = DashboardHome(currency: converter, savedSections: .constant(HomeSection.defaults), capacity: .constant(0), active: false, open: { _ in }, chooseCity: { _ in }, openRecord: { _ in }, openDocument: { _ in })
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
