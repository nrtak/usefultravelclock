import SwiftUI

struct TripPrivacySupportView: View {
    var body: some View {
        List {
            Section("Privacy") {
                Text("Trip Info stores travel entries, documents, translations, conversions, notes and selected reference photos on your iPhone. It does not operate its own cloud sync and includes no advertising or analytics SDK.")
                Text("Travel entries, travel drafts and imported documents are encrypted locally. Saved translations and conversions use iOS file protection. Some files may be included in device backups. The travel encryption key is specific to this device, so restoring files to another device may not restore access to encrypted travel information.")
            }
            Section("Camera & photos") {
                Text("Camera access is used for scanning and capture. Text recognition runs on the device. The photo picker provides only images you select; saving may keep a reference copy. Entered amounts, notes and photos are not sent to the exchange-rate provider.")
            }
            Section("Rates, weather & translation") {
                Text("Frankfurter supplies daily reference rates over HTTPS. Its service and network providers receive the requests and ordinary connection information. Rates are estimates; bank and card fees and final charges may differ.")
                Text("Weather uses Apple WeatherKit. Location search uses Apple Maps and sends the location query to Apple. Translation uses Apple's Translation framework; downloading languages requires internet. These services follow their providers' privacy practices.")
                Text("Downloaded or bundled rates and saved forecasts work offline. New data, new weather-location searches and language downloads require internet. Dates and freshness messages identify older information.")
            }
            Section("Permissions & data control") {
                Text("Camera, notification and optional authentication permissions are managed by iOS. App lock uses your iPhone's configured security; widgets are not protected. Reminder notifications omit private booking references and destinations.")
                Text("Delete saved entries within their screens. Saved translations and conversions offer Undo for the most recent deletion during the app session. Deleting a travel entry keeps its documents available to reassign or delete. Removing the app removes its local files; backups follow your iPhone's backup settings.")
            }
            Section("Support") {
                Text("Trip Info is maintained by Irvine Dynamics. Our support and privacy website is irvineapps.wordpress.com. This information page stays inside the app and does not open a website.")
                Text("When reporting a problem, include the version and build from About Trip Info, your iPhone model and iOS version, what you did, and what you expected. Remove private booking references and traveler information from screenshots.")
                Text("For battery reports, include the screen in use, whether live camera or translation was active, and approximate duration. iPhone Settings → Battery can help identify the period of use.")
            }
        }.navigationTitle("Privacy & support").navigationBarTitleDisplayMode(.inline)
    }
}
