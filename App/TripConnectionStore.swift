import SwiftUI
import Network

@MainActor final class TripConnectionStore: ObservableObject {
    static let shared = TripConnectionStore()
    @Published private(set) var isOffline = false
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "trip.connection")
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor [weak self] in self?.isOffline = offline }
        }
        monitor.start(queue: queue)
    }
}

struct TripRateStatus: View {
    @ObservedObject var store: ConverterStore
    @ObservedObject private var connection = TripConnectionStore.shared
    var body: some View {
        if connection.isOffline {
            Label(store.snapshot == nil ? "Offline · no saved rates" : "Offline · saved rates", systemImage: "wifi.slash")
        } else if store.updateFailed {
            Label(store.snapshot == nil ? "Rates unavailable · retry refresh" : "Refresh failed · saved rates", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        }
    }
}
