import SwiftUI
import LocalAuthentication

@MainActor
final class TripAppLock: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var unlocked = false
    @Published private(set) var authenticating = false
    @Published var error = ""
    private let defaults: UserDefaults
    private var context: LAContext?
    private var generation = UUID()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "trip-app-lock")
    }
    func setEnabled(_ value: Bool) async {
        if value {
            guard await authenticate() else { return }
            enabled = true
        } else {
            enabled = false
        }
        defaults.set(enabled, forKey: "trip-app-lock")
    }
    @discardableResult
    func authenticate() async -> Bool {
        guard !authenticating else { return false }
        authenticating = true; error = ""
        let request = UUID(); generation = request
        let auth = LAContext(); context = auth
        defer { if generation == request { authenticating = false; context = nil } }
        var failure: NSError?
        guard auth.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else {
            error = "Set up Face ID, Touch ID or a device passcode in iPhone Settings."
            return false
        }
        do {
            let accepted = try await auth.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Trip Info")
            guard generation == request else { return false }
            unlocked = accepted
            return accepted
        } catch {
            if generation == request { self.error = "Trip Info is locked. Tap Unlock to try again." }
            return false
        }
    }
    func lock() {
        generation = UUID(); context?.invalidate(); context = nil
        authenticating = false; unlocked = false
    }
}

struct TripAppLockGate<Content: View>: View {
    @ObservedObject var lock: TripAppLock
    @Environment(\.scenePhase) private var phase
    let content: () -> Content
    var body: some View {
        Group {
            if !lock.enabled || lock.unlocked {
                content()
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(.blue)
                    Text("Trip Info is locked").font(.title2.weight(.semibold))
                    Button { Task { await lock.authenticate() } } label: {
                        Label("Unlock", systemImage: "faceid").frame(minWidth: 120, minHeight: 44)
                    }.buttonStyle(.borderedProminent).disabled(lock.authenticating)
                    if !lock.error.isEmpty { Text(lock.error).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).ignoresSafeArea())
            }
        }
        .overlay {
            if lock.enabled && phase != .active {
                Color(.systemBackground).ignoresSafeArea().overlay(Label("Trip Info", systemImage: "lock.fill").font(.title2))
            }
        }
        .task { if lock.enabled && !lock.unlocked && phase == .active { await lock.authenticate() } }
        .onChange(of: phase) { _, value in
            if value == .background { lock.lock() }
        }
    }
}
