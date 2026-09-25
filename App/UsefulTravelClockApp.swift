//  Useful Travel Clock

import SwiftUI

@main
struct UsefulTravelClockApp: App {
    @StateObject private var store = UsefulTravelClockStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.preferredColorScheme)
                .tint(.primary)
        }
    }
}

/// Clocks / Converter tabs + bottom toolbar with Add city and Settings,
/// matching the web app's four-button bar.
struct RootView: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.colorScheme) private var scheme
    @State private var tab: Tab = .clocks
    @State private var showAddCity = false
    @State private var showSettings = false

    enum Tab { case clocks, converter }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch tab {
                case .clocks: ClocksView()
                case .converter: ConverterView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            toolbar
        }
        .background(Design.background(scheme))
        .sheet(isPresented: $showAddCity) { AddCitySheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    private var toolbar: some View {
        HStack {
            tabButton("Clocks", systemImage: "clock") { tab = .clocks }
            tabButton("Converter", systemImage: "arrow.left.arrow.right") { tab = .converter }
            tabButton("Add city", systemImage: "plus") { showAddCity = true }
            tabButton("Settings", systemImage: "gearshape") { showSettings = true }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(Design.background(scheme).opacity(0.9).ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(_ label: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage).font(.system(size: 19, weight: .medium))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(
                (tab == .clocks && label == "Clocks") || (tab == .converter && label == "Converter")
                    ? Design.foreground(scheme)
                    : Design.mutedForeground(scheme)
            )
        }
    }
}
