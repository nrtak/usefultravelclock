import SwiftUI

@main
struct TravelToolsApp: App {
    @StateObject private var currency = ConverterStore()
    @StateObject private var clock = UsefulTravelClockStore()
    var body: some Scene {
        WindowGroup {
            TravelDashboard(currency: currency)
                .environmentObject(clock)
                .preferredColorScheme(clock.preferredColorScheme)
        }
    }
}
