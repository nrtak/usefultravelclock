import SwiftUI
import UserNotifications

@MainActor protocol TripNotificationClient {
    func requestAccess() async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func pending() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ identifiers: [String])
}

struct SystemTripNotifications: TripNotificationClient {
    private let center = UNUserNotificationCenter.current()
    func requestAccess() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

@MainActor final class TripReminderStore: ObservableObject {
    @Published private(set) var message: String?
    private let client: any TripNotificationClient
    private var generation = UUID()
    private var synchronizing = false
    private var latestRecords: [TravelRecord] = []
    private var latestNow = Date()
    private var accessIssue: String?
    init(client: (any TripNotificationClient)? = nil) { self.client = client ?? SystemTripNotifications() }

    func requestAccess() async -> Bool {
        do {
            let allowed = try await client.requestAccess()
            accessIssue = allowed ? nil : "Travel details can still be saved. Notifications are off; enable Tama World Clock notifications in iPhone Settings to receive reminders."
            message = accessIssue
            return allowed
        } catch { accessIssue = "Travel details can still be saved. Could not enable reminders: " + error.localizedDescription; message = accessIssue; return false }
    }

    static func fireDate(for record: TravelRecord) -> Date? {
        guard let minutes = record.reminderMinutes, [15, 30, 60, 120, 1440].contains(minutes) else { return nil }
        return record.start.addingTimeInterval(-Double(minutes) * 60)
    }

    static func request(for record: TravelRecord, now: Date) -> UNNotificationRequest? {
        guard let date = fireDate(for: record), date > now else { return nil }
        let content = UNMutableNotificationContent()
        // Keep private booking references and destinations off the lock screen.
        content.title = "Tama World Clock reminder"
        content.body = "Your \(record.kind == "Hotel" ? "check-in" : "departure") is coming up. Open Tama World Clock to review the local time and travel details."
        content.sound = .default
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.calendar = calendar; components.timeZone = .gmt
        return UNNotificationRequest(identifier: "trip-reminder-" + record.id.uuidString, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }

    func synchronize(records: [TravelRecord], now: Date = Date()) async {
        generation = UUID(); latestRecords = records; latestNow = now
        guard !synchronizing else { return }
        synchronizing = true
        defer { synchronizing = false; latestRecords = [] }
        repeat {
        let revision = generation
        // Leave room for other notifications and stay within iOS's pending limit.
        let desired = latestRecords.sorted { (Self.fireDate(for: $0) ?? .distantFuture) < (Self.fireDate(for: $1) ?? .distantFuture) }.compactMap { Self.request(for: $0, now: latestNow) }
        let requests = Array(desired.prefix(50))
        let pending = await client.pending()
        let authorization = await client.authorizationStatus()
        if generation != revision { continue }
        switch authorization {
        case .denied: accessIssue = "Notifications are off; enable Tama World Clock notifications in iPhone Settings to receive reminders."
        case .notDetermined: accessIssue = "Reminder permission is needed. Save a travel entry with a reminder to enable notifications."
        default: accessIssue = nil
        }
        let ids = Set(requests.map(\.identifier))
        client.remove(pending.filter { $0.identifier.hasPrefix("trip-reminder-") && !ids.contains($0.identifier) }.map(\.identifier))
        do {
            for request in requests {
                if generation != revision { break }
                if let previous = pending.first(where: { $0.identifier == request.identifier }) {
                    let oldTrigger = previous.trigger as? UNCalendarNotificationTrigger
                    let newTrigger = request.trigger as? UNCalendarNotificationTrigger
                    if oldTrigger?.dateComponents == newTrigger?.dateComponents,
                       previous.content.title == request.content.title,
                       previous.content.body == request.content.body { continue }
                    // Remove the old schedule first so a failed replacement cannot fire at the wrong time.
                    client.remove([previous.identifier])
                }
                try await client.add(request)
            }
            if generation == revision { message = !desired.isEmpty && accessIssue != nil ? accessIssue : (desired.count > 50 ? "The next 50 reminders are scheduled. Open Tama World Clock during your travels to schedule later ones." : nil) }
        } catch { if generation == revision { message = "Travel details saved, but a reminder could not be scheduled. Retry from the travel entry: " + error.localizedDescription } }
        if generation == revision { break }
        } while true
    }
}
