import SwiftUI

struct TripGettingStartedView: View {
    var body: some View {
        List {
            Section("1 · Add your booking") {
                Text("Open My Trip and tap Add travel entry. Enter your hotel, flight or transport details. Choose each location’s time zone and review the dates before saving.")
                NavigationLink("Open My Trip") { TravelRecordsView() }
            }
            Section("2 · Keep your ticket handy") {
                Text("Open Documents to add a PDF or photo from Files or Photos. Assign it to the booking so it is easy to find when traveling.")
                NavigationLink("Open Documents") { TripDocumentsView() }
            }
            Section("3 · Prepare for offline use") {
                Text("On Home, open Before you leave. Check saved tickets, refresh rates and weather, and prepare your translation languages while connected.")
                NavigationLink("Prepare translation languages") { TripTranslateView().navigationTitle("Translate") }
            }
            Section("4 · Check your reminders") {
                Text("Choose a reminder in your booking if you want one. Allow notifications, then check iPhone Focus settings. Reminder times follow the booking’s scheduled instant.")
            }
        }.navigationTitle("Getting started")
    }
}
