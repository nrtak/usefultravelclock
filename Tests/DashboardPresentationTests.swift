import XCTest
import SwiftUI
import UIKit
@testable import UsefulTravelClock

final class DashboardPresentationTests: XCTestCase {
    @MainActor
    func testWeatherSheetGetsDashboardStoresWithoutAnAncestorWeatherStore() async throws {
        let suite = "WeatherPresentation-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        TripConnectionStore.shared.setTutorialOffline(true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            TripConnectionStore.shared.setTutorialOffline(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        let clock = UsefulTravelClockStore(defaults: defaults)
        let tokyo = try XCTUnwrap(clock.allCities.first { $0.id == "tyo" })
        defaults.set(tokyo.id, forKey: "travel-destination")
        let currency = ConverterStore(preferences: defaults, cacheURL: directory.appendingPathComponent("rates.json"), isOffline: { true })
        let trip = TripStore(directory: directory.appendingPathComponent("trip"))
        trip.unlocked = true
        let weather = TripWeatherStore(directory: directory.appendingPathComponent("weather"))
        weather.installTutorialWeather(for: tokyo, celsius: 20)
        let dashboard = TravelDashboard(tutorialCurrency: currency, trip: trip, weather: weather, initialTool: .weather)
            .defaultAppStorage(defaults)
            .environmentObject(clock)
            .environmentObject(TripAppLock(defaults: defaults))
            .environmentObject(TripDocumentInbox())
            .environment(\.scenePhase, .active)
        // Match the app's environment: the dashboard owns and provides weather/trip.
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = UIHostingController(rootView: dashboard)
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer {
            controller.dismiss(animated: false)
            window.isHidden = true
            previous?.makeKeyAndVisible()
        }
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertNotNil(controller.presentedViewController, "Weather must open through the production sheet presenter")
        XCTAssertNotNil(weather.cache[try XCTUnwrap(weather.locations[tokyo.id]).id])
        XCTAssertEqual(weather.credit.legalURL.scheme, "https")
    }
}
