import SwiftUI

struct CurrencyInformationView: View {
    var body: some View {
        List {
            Section("Exchange rates") {
                Text("Frankfurter supplies daily reference rates. Conversions are estimates; bank and card rates, fees and final charges may differ.")
                Text("Rate dates and the last check appear with the converter. Refresh requires internet. Downloaded rates are kept for offline use; a dated bundled reference snapshot is available on first launch. The label identifies bundled rates. Values are estimates, not live market quotes.")
                Link("Frankfurter & data sources", destination: URL(string: "https://frankfurter.dev/")!)
                Link("Provider terms", destination: URL(string: "https://frankfurter.dev/license/")!)
            }
            Section("Camera & selected photos") {
                Text("Text recognition runs on your device. Camera access is used for live scanning and capture. Choosing Photo provides the selected image for recognition; saving keeps a reference copy with your entry.")
                Text("Marked prices are read by default. Include unmarked numbers uses the From currency for standalone amounts. Review prices, quantities and units before saving.")
            }
            Section("Saved information") {
                Text("Amounts, notes and attached photos are stored on this device and are not sent to the exchange-rate provider. They may be included in device backups. The app does not provide its own cloud sync.")
                Text("Travel records are encrypted on the device. Saved translations and unit conversions are stored locally with iOS file protection; they do not use the travel-record encryption format.")
                Text("Undo for saved-conversion deletion is available during the current app session. Reference photos are kept so they can be restored.")
            }
            Section("Network services") {
                Text("Exchange-rate requests use HTTPS. The rate provider and network infrastructure process those requests. Entered amounts, notes and photos are not included.")
                Text("Weather uses Apple WeatherKit, and city search uses Apple Maps. Translation uses Apple's Translation framework; language resources may need downloading.")
                Text("The app adds no analytics or advertising SDK.")
            }
            Section("App lock") {
                Text("Optional Lock app uses Face ID, Touch ID or the device passcode already configured on your iPhone. It locks when you leave the app. My Trip has no separate lock; widgets are not protected.")
                Text("An older protected travel record may require device authentication once when first opened after an update.")
            }
            Section("Offline limits") {
                Text("Saved entries and downloaded rates remain accessible offline. Fresh rates, fresh weather, weather location search and language downloads need a connection. Clocks, built-in city search, units, text recognition, saved entries and the Help video work offline. Translate needs the selected languages installed first. iCloud-only photos need downloading before use. Check the saved-data label and update time before relying on older information.")
            }
        }.navigationTitle("Rates & privacy").navigationBarTitleDisplayMode(.inline)
    }
}
