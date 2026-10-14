import SwiftUI
import VisionKit
import UIKit

enum TripCameraActivity {
    static func shouldRun(visible: Bool, active: Bool, recognizing: Bool, pendingCapture: Bool) -> Bool {
        visible && active && (recognizing || pendingCapture)
    }
}

struct LiveTextCamera: View {
    #if DEBUG
    static var tutorialImage: UIImage?
    #endif
    @Environment(\.scenePhase) private var phase
    @State private var visible = false
    @State private var completedCaptureID: UUID?
    var recognitionEnabled = true
    var onText: (String) -> Void
    var onError: (String) -> Void
    var resetID: UUID? = nil
    var captureID: UUID? = nil
    var onPhoto: ((UIImage) -> Void)? = nil
    private var pendingCapture: UUID? { captureID == completedCaptureID ? nil : captureID }
    var body: some View {
        Group {
            if TripCameraActivity.shouldRun(visible: visible, active: phase == .active, recognizing: recognitionEnabled, pendingCapture: pendingCapture != nil) {
                TripScannerController(recognitionEnabled: recognitionEnabled, onText: onText, onError: { message in
                    completedCaptureID = captureID; onError(message)
                }, resetID: resetID, captureID: pendingCapture, onPhoto: { image in
                    completedCaptureID = captureID; onPhoto?(image)
                })
            } else {
                Color(.secondarySystemBackground).overlay {
                    Label("Camera paused", systemImage: "camera").foregroundStyle(.secondary)
                }
            }
        }.onAppear { visible = true }
        .onDisappear { visible = false; cancelCapture() }
        .onChange(of: phase) { _, value in if value != .active { cancelCapture() } }
        .onChange(of: resetID) { _, _ in cancelCapture() }
    }
    private func cancelCapture() {
        guard pendingCapture != nil else { return }
        completedCaptureID = captureID
        onError("Photo capture interrupted. Tap the camera button to retry.")
    }
}

private struct TripScannerController: UIViewControllerRepresentable {
    var recognitionEnabled = true
    var onText: (String) -> Void
    var onError: (String) -> Void
    var resetID: UUID? = nil
    var captureID: UUID? = nil
    var onPhoto: ((UIImage) -> Void)? = nil
    func makeCoordinator() -> Coordinator { let coordinator = Coordinator(onText: onText, onError: onError); coordinator.recognitionEnabled = recognitionEnabled; return coordinator }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .balanced, recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        #if DEBUG
        if let image = LiveTextCamera.tutorialImage {
            let preview = UIImageView(image: image)
            preview.contentMode = .scaleAspectFill; preview.clipsToBounds = true
            preview.frame = scanner.view.bounds; preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            scanner.view.addSubview(preview)
            return scanner
        }
        #endif
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            do { try scanner.startScanning() } catch { DispatchQueue.main.async { onError(error.localizedDescription) } }
        } else { DispatchQueue.main.async { onError("Live camera unavailable. Enable camera access in Settings or choose a photo.") } }
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        #if DEBUG
        if LiveTextCamera.tutorialImage != nil { return }
        #endif
        context.coordinator.recognitionEnabled = recognitionEnabled
        context.coordinator.onText = onText
        context.coordinator.onError = onError
        if resetID != context.coordinator.lastResetID {
            context.coordinator.lastResetID = resetID
            context.coordinator.resetRecognition()
        }
        if let captureID, captureID != context.coordinator.lastCaptureID {
            context.coordinator.lastCaptureID = captureID
            let coordinator = context.coordinator
            let generation = coordinator.lastResetID
            coordinator.captureTask?.cancel()
            coordinator.captureTask = Task { @MainActor in
                do {
                    let image = try await scanner.capturePhoto()
                    if !Task.isCancelled && !coordinator.stopped && generation == coordinator.lastResetID && captureID == coordinator.lastCaptureID { onPhoto?(image) }
                } catch {
                    if !Task.isCancelled && !coordinator.stopped && generation == coordinator.lastResetID && captureID == coordinator.lastCaptureID { onError("Couldn’t capture photo. Try again.") }
                }
            }
        }
    }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { coordinator.stopped = true; coordinator.captureTask?.cancel(); coordinator.resetRecognition(); scanner.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var recognitionEnabled = true
        private var latest: [RecognizedItem] = []
        private var pending: Task<Void, Never>?
        var onText: (String) -> Void
        var onError: (String) -> Void
        private var previous = ""
        var lastResetID: UUID?
        func resetRecognition() { captureTask?.cancel(); captureTask = nil; pending?.cancel(); pending = nil; latest = []; previous = "" }
        var captureTask: Task<Void, Never>?
        var lastCaptureID: UUID?
        var stopped = false
        init(onText: @escaping (String) -> Void, onError: @escaping (String) -> Void) { self.onText = onText; self.onError = onError }
        func publish(_ items: [RecognizedItem]) {
            guard recognitionEnabled && !stopped else { return }
            latest = items
            guard pending == nil else { return }
            // Coalesce rapid tracking callbacks into one current reading.
            pending = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
                guard let self else { return }
                self.pending = nil
                guard self.recognitionEnabled && !self.stopped else { return }
                self.deliver(self.latest)
            }
        }
        private func deliver(_ items: [RecognizedItem]) {
            let text = items.compactMap { item -> String? in if case .text(let value) = item { return value.transcript }; return nil }.joined(separator: "\n")
            if text != previous { previous = text; onText(text) }
        }
        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { publish(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { publish(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) { publish(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) { onError("Live camera unavailable. Choose a photo instead.") }
    }
}

