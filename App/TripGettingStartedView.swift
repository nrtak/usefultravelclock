import SwiftUI

// Information only: this guide does not open features or request permissions.
struct TripGettingStartedView: View {
    var body: some View {
        List {
            Section("Home") { Text("Choose Home and Destination cities to compare local times. Edit either currency amount to convert both ways. Full converter opens the currency tools. Current or next travel details and a document shortcut appear below the clocks and weather.") }
            Section("Conversions & units") { Text("Choose From and To currencies, enter an amount, or swap them. Rates are dated estimates; bank rates and fees may differ. Multiple prices supports addition and subtraction. Review recognized prices and quantities before saving. Unit conversion handles distance, temperature, volume and other measurements.") }
            Section("Camera & photos") { Text("Live camera reads prices, measurements or text. Pause stops the scanner; Resume starts it again. Use the shutter for a reference photo, or choose an existing photo. Clear lighting helps recognition. Include unmarked numbers may also detect quantities or product IDs, so review every value.") }
            Section("Saved conversions") { Text("Save an amount with a note and optional reference photo. Open Saved to revisit it. Swipe to delete; Undo restores the most recent deletion during the current app session.") }
            Section("World Time") { Text("Compare cities with the slider; Return to now restores live time. Hold a city to edit or reorder it. Yesterday and Tomorrow compare each city's date with Home.") }
            Section("My Trip") {
                Text("Add a hotel, flight or transport booking. Select departure and arrival locations, review local dates and times, then Save. Today & next shows relevant bookings; Today follows your iPhone's date. Search by booking name, route, traveler, reference or note.")
                Text("Unfinished edits are saved as encrypted drafts. Resume or discard them in My Trip. Optional reminders use the booking's scheduled instant. Notification and Focus settings affect delivery.")
            }
            Section("Documents") { Text("The folder icon opens Documents. Import PDFs or images, assign a booking, and label traveler and type. Sort by date, trip or type, or filter unassigned documents. Open, rename, replace, share or delete a copy from its details. Hold a booking for document shortcuts. Resume cancelled imports from Documents.") }
            Section("Translate") { Text("Choose languages, then enter text or use Camera or Photo. Prepare for offline use downloads language resources while connected. Saved translations supports titles, search, editing, deletion and Undo. Leaving an edited translation prompts Save or Discard. Repeated Save taps for unchanged content keep one entry.") }
            Section("Before you leave") { Text("Check travel details, readable tickets, rates, weather, languages and reminders. Refresh while connected and open a saved ticket in airplane mode. Keep originals in Files too. Older weather and rates may need refreshing; iCloud-only photos may need downloading.") }
            Section("Settings & app lock") { Text("Settings offers themes, clock display choices and optional Face ID, Touch ID or device-passcode protection. Hold a bottom tab to reorder it. Choices and tab order are remembered. Widgets are outside the app lock.") }
            Section("Battery & troubleshooting") { Text("Live camera and translation use more power than viewing saved information. Pause when you have the reading you need. The scanner shuts down when its screen is hidden or the app is inactive. For recognition problems, improve lighting or choose a clearer photo. For rates or weather, reconnect and Refresh. Low-storage errors explain how to free space and retry.") }
        }.navigationTitle("App guide").navigationBarTitleDisplayMode(.inline)
    }
}
