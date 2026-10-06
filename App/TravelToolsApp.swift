import SwiftUI

@main
struct TravelToolsApp: App {
    @StateObject private var currency = ConverterStore()
    @StateObject private var clock = UsefulTravelClockStore()
    @StateObject private var appLock = TripAppLock()
    var body: some Scene {
        WindowGroup {
            TripAppLockGate(lock: appLock) { TravelDashboard(currency: currency) }
                .environmentObject(appLock)
                .environmentObject(clock)
                .preferredColorScheme(clock.preferredColorScheme)
        }
    }
}
