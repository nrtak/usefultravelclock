import XCTest
import SwiftUI
import UIKit
@testable import UsefulTravelClock

// Capture the production views with explicit example data. No substitute layouts.
final class TutorialCaptureTests: XCTestCase {
    @MainActor
    func testCaptureTutorialScreens() async throws {
        let suite = "TutorialCaptures-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        let standard = UserDefaults.standard
        let keys = ["travel-destination", "trip-selected-tab", "trip-tab-order", "trip-tab-reorder-hint-seen", "trip-translation-source", "trip-translation-target", "trip-unit-category", "trip-unit-source", "trip-unit-target"]
        let old = keys.map { standard.object(forKey: $0) }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer {
            for (key, value) in zip(keys, old) { if let value { standard.set(value, forKey: key) } else { standard.removeObject(forKey: key) } }
            preferences.removePersistentDomain(forName: suite)
            LiveTextCamera.tutorialImage = nil
            TripConnectionStore.shared.setTutorialOffline(nil)
            try? FileManager.default.removeItem(at: temporary)
        }
        let bundle = Bundle(for: Self.self)
        let menu = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "cafe-menu", withExtension: "jpg")))
        let sign = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "station-sign", withExtension: "jpg")))
        let luggage = try Data(contentsOf: XCTUnwrap(bundle.url(forResource: "luggage-scale", withExtension: "jpg")))
        let now = Date()
        let rates = RateSnapshot(fetchedAt: now, rows: [Rate(date: "2026-10-05", base: "USD", quote: "JPY", rate: 150)])
        let ratesURL = temporary.appendingPathComponent("rates.json")
        try JSONEncoder().encode(rates).write(to: ratesURL)
        let converter = ConverterStore(preferences: preferences, cacheURL: ratesURL, isOffline: { true })
        converter.source = "JPY"; converter.target = "USD"; converter.amount = "500"
        converter.multiplePriceItems = [ItemPrice(text: "500"), ItemPrice(text: "400"), ItemPrice(text: "650")]
        let saved = SavedConversions(directory: temporary.appendingPathComponent("Saved"))
        var draft = try XCTUnwrap(converter.savedDraft())
        draft.note = "Coffee at the station cafe · example"
        try saved.save(draft, photo: menu)
        saved.clearSaveNotice()
        let savedItem = try XCTUnwrap(saved.items.first)
        let clock = UsefulTravelClockStore(defaults: preferences)
        let la = try XCTUnwrap(clock.allCities.first { $0.name == "Los Angeles" })
        let tokyo = try XCTUnwrap(clock.allCities.first { $0.name == "Tokyo" })
        clock.homeMode = .manual; clock.homeCityID = la.id
        clock.cityIDs = [la.id, tokyo.id] + ["London", "Melbourne", "Paris"].compactMap { name in clock.allCities.first { $0.name == name }?.id }
        standard.set(tokyo.id, forKey: "travel-destination")
        standard.set("0,1,2,3,4", forKey: "trip-tab-order")
        standard.set(true, forKey: "trip-tab-reorder-hint-seen")
        standard.set("ja", forKey: "trip-translation-source")
        standard.set("en", forKey: "trip-translation-target")
        standard.set("Weight", forKey: "trip-unit-category")
        standard.set("kg", forKey: "trip-unit-source")
        standard.set("lb", forKey: "trip-unit-target")
        let trip = TripStore(directory: temporary.appendingPathComponent("Trip")); trip.unlocked = true
        let weather = TripWeatherStore()
        weather.installTutorialWeather(for: la, celsius: 25)
        weather.installTutorialWeather(for: tokyo, celsius: 20)
        TripConnectionStore.shared.setTutorialOffline(true)
        let lock = TripAppLock(defaults: preferences)
        func screen<V: View>(_ name: String, _ view: V, bottom: Bool = false) async throws {
            try await capture(name, view: view.environmentObject(clock).environmentObject(trip).environmentObject(weather).environmentObject(lock).environment(\.scenePhase, .active).preferredColorScheme(.light), bottom: bottom)
        }
        func dashboard(tab: Int, shift: Double = 0, reorder: Bool = false) -> TravelDashboard {
            standard.set(tab, forKey: "trip-selected-tab")
            return TravelDashboard(tutorialCurrency: converter, trip: trip, weather: weather, shift: shift, reordering: reorder)
        }
        try await screen("00-home", dashboard(tab: 0))
        try await screen("01-currency", dashboard(tab: 1))
        try await screen("02-multiple", ItemConversionView(store: converter))
        LiveTextCamera.tutorialImage = UIImage(data: menu)
        try await screen("03-camera", NavigationStack { PriceImageView(tutorialStore: converter, saved: saved, photo: menu, held: false).toolbar { ToolbarItem(placement: .confirmationAction) { Text("Done").foregroundStyle(.blue) } } })
        try await screen("04-prices", NavigationStack { PriceImageView(tutorialStore: converter, saved: saved, photo: menu, held: true) }, bottom: true)
        LiveTextCamera.tutorialImage = nil
        try await screen("05-save", SaveConversionView(tutorialDraft: draft, photo: menu, saved: saved))
        try await screen("05-save-note", SaveConversionView(tutorialDraft: draft, photo: menu, saved: saved), bottom: true)
        try await screen("06-saved", SavedConversionsView(saved: saved))
        try await screen("06-saved-detail", TutorialSavedViews.detail(savedItem, photoURL: saved.photoURL(for: savedItem)))
        try await screen("07-units", NavigationStack { TripUnitsView(tutorialPhoto: luggage) })
        try await screen("08-world-now", dashboard(tab: 2))
        try await screen("08-world-compare", dashboard(tab: 2, shift: 3))
        try await screen("09-translate", NavigationStack { TripTranslateView(tutorialPhoto: sign, completed: false).navigationTitle("Translate") })
        try await screen("09-translate-result", NavigationStack { TripTranslateView(tutorialPhoto: sign, completed: true).navigationTitle("Translate") }, bottom: true)
        var hotel = TravelRecord(); hotel.name = "Tokyo Garden Hotel"; hotel.reference = "DEMO-1042"; hotel.from = "1-2-3 Example Street, Tokyo"; hotel.note = "Late arrival · example booking"; hotel.departureCity = "Tokyo"; hotel.arrivalCity = "Tokyo"; hotel.departureTimeZone = tokyo.timeZoneID; hotel.arrivalTimeZone = tokyo.timeZoneID; hotel.start = now.addingTimeInterval(86400); hotel.end = now.addingTimeInterval(4 * 86400)
        var flight = TravelRecord(); flight.kind = "Flight"; flight.name = "Example Air"; flight.reference = "EA 101"; flight.from = "Los Angeles (LAX)"; flight.to = "Tokyo (HND)"; flight.departureCity = "Los Angeles"; flight.arrivalCity = "Tokyo"; flight.departureTimeZone = la.timeZoneID; flight.arrivalTimeZone = tokyo.timeZoneID; flight.start = now.addingTimeInterval(3600); flight.end = flight.start.addingTimeInterval(12 * 3600); flight.note = "Terminal 2 · sample details"
        var train = TravelRecord(); train.kind = "Transport"; train.name = "Airport Express"; train.reference = "DEMO-205"; train.from = "Haneda Airport"; train.to = "Tokyo Station"; train.departureCity = "Tokyo"; train.arrivalCity = "Tokyo"; train.departureTimeZone = tokyo.timeZoneID; train.arrivalTimeZone = tokyo.timeZoneID; train.start = flight.end.addingTimeInterval(7200); train.end = train.start.addingTimeInterval(1800); train.note = "Platform 2 · example journey"
        for (name, record) in [("10-hotel", hotel), ("11-flight", flight), ("12-transport", train)] {
            try await screen(name, RecordEditor(record: record))
            try await screen(name + "-notes", RecordEditor(record: record), bottom: true)
        }
        trip.records = [hotel, flight, train]
        try await screen("12-trip-list", dashboard(tab: 3))
        try await screen("13-reorder", dashboard(tab: 2, reorder: true))
        try await screen("14-weather", dashboard(tab: 0), bottom: true)
        try await screen("15-settings", TripSettingsView())
        try await screen("15-settings-help", TripSettingsView(), bottom: true)
        try await screen("16-offline", dashboard(tab: 0))
    }
    @MainActor
    private func capture<V: View>(_ name: String, view: V, bottom: Bool) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let controller = UIHostingController(rootView: view)
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(700))
        controller.view.layoutIfNeeded()
        if bottom {
            func scroll(_ view: UIView) {
                if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                }
                for child in view.subviews { scroll(child) }
            }
            scroll(controller.view)
            try await Task.sleep(for: .milliseconds(200))
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let png = try XCTUnwrap(image.pngData())
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TutorialCaptures")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appendingPathComponent(name + ".png"))
        XCTAssertGreaterThan(png.count, 10000, "Capture should contain the rendered app screen")
    }
}
