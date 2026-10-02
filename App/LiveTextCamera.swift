import SwiftUI
import VisionKit

struct LiveTextCamera: UIViewControllerRepresentable {
    var onText: (String) -> Void
    var onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onText: onText, onError: onError) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .balanced, recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            do { try scanner.startScanning() } catch { DispatchQueue.main.async { onError(error.localizedDescription) } }
        } else { DispatchQueue.main.async { onError("Live camera unavailable. Enable camera access in Settings or choose a photo.") } }
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onText = onText
        context.coordinator.onError = onError
    }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { scanner.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onText: (String) -> Void
        var onError: (String) -> Void
        private var previous = ""
        init(onText: @escaping (String) -> Void, onError: @escaping (String) -> Void) { self.onText = onText; self.onError = onError }
        func publish(_ items: [RecognizedItem]) {
            let text = items.compactMap { item -> String? in if case .text(let value) = item { return value.transcript }; return nil }.joined(separator: "\n")
            if text != previous { previous = text; onText(text) }
        }
        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { publish(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { publish(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) { publish(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) { onError("Live camera unavailable. Choose a photo instead.") }
    }
}
