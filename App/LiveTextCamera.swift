import SwiftUI
import VisionKit
import UIKit

struct LiveTextCamera: UIViewControllerRepresentable {
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
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            do { try scanner.startScanning() } catch { DispatchQueue.main.async { onError(error.localizedDescription) } }
        } else { DispatchQueue.main.async { onError("Live camera unavailable. Enable camera access in Settings or choose a photo.") } }
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
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
            Task { @MainActor in
                do {
                    let image = try await scanner.capturePhoto()
                    if !coordinator.stopped && generation == coordinator.lastResetID { onPhoto?(image) }
                } catch {
                    if !coordinator.stopped && generation == coordinator.lastResetID { onError("Couldn’t capture photo. Try again.") }
                }
            }
        }
    }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { coordinator.stopped = true; coordinator.resetRecognition(); scanner.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var recognitionEnabled = true
        private var latest: [RecognizedItem] = []
        private var pending: Task<Void, Never>?
        var onText: (String) -> Void
        var onError: (String) -> Void
        private var previous = ""
        var lastResetID: UUID?
        func resetRecognition() { pending?.cancel(); pending = nil; latest = []; previous = "" }
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
