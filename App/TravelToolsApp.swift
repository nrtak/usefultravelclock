import SwiftUI

@main
struct TravelToolsApp: App {
    @StateObject private var currency = ConverterStore()
    @StateObject private var clock = UsefulTravelClockStore()
    @StateObject private var appLock = TripAppLock()
    @StateObject private var documentInbox = TripDocumentInbox()
    var body: some Scene {
        WindowGroup {
            TripAppLockGate(lock: appLock) { TravelDashboard(currency: currency) }
                .environmentObject(documentInbox)
                .onOpenURL { documentInbox.receive($0) }
                .environmentObject(appLock)
                .environmentObject(clock)
                .preferredColorScheme(clock.preferredColorScheme)
        }
    }
}

