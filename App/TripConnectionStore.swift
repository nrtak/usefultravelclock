import SwiftUI
import Network

struct TripVisibleTimelineContext { let date: Date }

struct TripVisibleTimeline<Content: View>: View {
    @Environment(\.scenePhase) private var phase
    @State private var visible = false
    let interval: TimeInterval
    let enabled: Bool
    private let content: (TripVisibleTimelineContext) -> Content
    init(interval: TimeInterval, enabled: Bool = true, @ViewBuilder content: @escaping (TripVisibleTimelineContext) -> Content) {
        self.interval = interval; self.enabled = enabled; self.content = content
    }
    var body: some View {
        Group {
            if visible && phase == .active && enabled {
                TimelineView(.periodic(from: .now, by: interval)) { context in content(TripVisibleTimelineContext(date: context.date)) }
            } else {
                content(TripVisibleTimelineContext(date: Date()))
            }
        }.onAppear { visible = true }.onDisappear { visible = false }
    }
}

struct TripRefreshStamp: View {
    let success: Date?
    let fallback: String
    @State private var fresh = false
    var body: some View {
        Text(fresh ? "Updated just now" : fallback)
            .foregroundStyle(fresh ? Color.teal : Color.secondary)
            .task(id: success) {
                let remaining = TripRefreshFreshness.remaining(success: success, now: Date())
                fresh = remaining > 0
                guard fresh else { return }
                do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) } catch { return }
                guard !Task.isCancelled else { return }; fresh = false
            }
    }
}

enum TripRefreshFreshness {
    static func remaining(success: Date?, now: Date) -> Double {
        guard let success else { return 0 }
        let age = now.timeIntervalSince(success)
        return age >= 0 && age < 8 ? 8 - age : 0
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
        if store.cacheWriteFailed {
            Label("Rates updated for this session · could not save for offline use", systemImage: "exclamationmark.triangle")
        }
        if connection.isOffline {
            Label(store.snapshot == nil ? "Offline · no saved rates" : (store.usingBundledRates ? "Offline · included rates" : "Offline · saved rates"), systemImage: "wifi.slash")
        } else if store.updateFailed {
            Label(store.snapshot == nil ? "Rates unavailable · retry refresh" : (store.usingBundledRates ? "Refresh failed · included rates" : "Refresh failed · saved rates"), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        }
    }
}


