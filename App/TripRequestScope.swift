import SwiftUI

// Weather searches may finish out of order even when cancellation is requested.
// Only the latest visible request is allowed to update its screen.
@MainActor final class TripRequestScope: ObservableObject {
    private var revision = UUID()
    private var task: Task<Void, Never>?

    @discardableResult
    func run(_ operation: @escaping @MainActor (UUID) async -> Void) -> Task<Void, Never> {
        cancel()
        let current = revision
        let next = Task { @MainActor [weak self] in
            guard self?.accepts(current) == true else { return }
            await operation(current)
            if self?.revision == current { self?.task = nil }
        }
        task = next
        return next
    }
    func accepts(_ value: UUID) -> Bool { revision == value && !Task.isCancelled }
    func cancel() { revision = UUID(); task?.cancel(); task = nil }
}
