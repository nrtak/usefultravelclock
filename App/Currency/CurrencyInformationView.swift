import SwiftUI

struct CurrencyInformationView: View {
    var body: some View {
        List {
            Section("Exchange rates") {
                Text("Frankfurter provides daily reference rates. These are estimates; bank and card rates may differ. Rate dates and the last refresh appear beside the converter. Refresh requires internet; previously downloaded rates remain available offline.")
                Link("Frankfurter and data sources", destination: URL(string: "https://frankfurter.dev/")!)
                Link("Provider terms", destination: URL(string: "https://frankfurter.dev/license/")!)
            }
            Section("Photos & live camera") {
                Text("Text recognition runs on your device. Marked prices are read by default. Include unmarked numbers accepts standalone amounts using your selected From currency; review them for quantities or product IDs. Recognized prices stay visible until Scan again. Camera access is used for live scanning or taking a photo.")
            }
            Section("Privacy") {
                Text("Entered amounts, conversion notes and attached photos are not sent to the rate provider. Saved conversions stay on this device and may be included in device backups. Rate requests go over HTTPS; the provider and network infrastructure process those requests. The app adds no analytics.")
            }
            Section("Travel data & other services") {
                Text("Travel records are encrypted on this device and unlock using device authentication. Translation notes, images and unit conversions stay locally. Weather requests go to Apple WeatherKit; city search uses Apple Maps. Apple’s translation framework may collect API usage metrics; translated content is not included.")
            }
            Section("Currency search") {
                Text("Search by currency name, country or code. Conversion availability depends on the provider; unavailable conversions are clearly indicated.")
            }
        }.navigationTitle("Rates & privacy").navigationBarTitleDisplayMode(.inline)
    }
}
