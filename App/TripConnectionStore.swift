import SwiftUI
import Network

struct TripRefreshStamp: View {
    let success: Date?
    let fallback: String
    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { context in
            let fresh = success.map { context.date.timeIntervalSince($0) < 8 } ?? false
            Text(fresh ? "Updated just now" : fallback)
                .foregroundStyle(fresh ? Color.teal : Color.secondary)
        }
    }
}

@MainActor final class TripConnectionStore: ObservableObject {
    static let shared = TripConnectionStore()
    @Published private(set) var isOffline = false
    #if DEBUG
    private var tutorialOffline: Bool?
    func setTutorialOffline(_ value: Bool?) { tutorialOffline = value; if let value { isOffline = value } }
    #endif
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "trip.connection")
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor [weak self] in
                #if DEBUG
                self?.isOffline = self?.tutorialOffline ?? offline
                #else
                self?.isOffline = offline
                #endif
            }
        }
        monitor.start(queue: queue)
    }
}

struct TripRateStatus: View {
    @ObservedObject var store: ConverterStore
    @ObservedObject private var connection = TripConnectionStore.shared
    var body: some View {
        if connection.isOffline {
            Label(store.snapshot == nil ? "Offline · no saved rates" : (store.usingBundledRates ? "Offline · using bundled reference rates" : "Offline · using saved reference rates"), systemImage: "wifi.slash")
        } else if store.updateFailed {
            Label(store.snapshot == nil ? "Rates unavailable · retry refresh" : (store.usingBundledRates ? "Refresh failed · using bundled reference rates" : "Refresh failed · using saved reference rates"), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        }
    }
}

