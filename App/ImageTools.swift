import SwiftUI
import PhotosUI
import Vision
import Translation
import UIKit

struct RecognizedLine: Identifiable {
    let id = UUID()
    let text: String
}
enum ImageText {
    static func read(_ data: Data) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            try VNImageRequestHandler(data: data).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first }.map { RecognizedLine(text: $0.string) }
        }.value
    }
}
struct PriceImageView: View {
    @ObservedObject var store: ConverterStore
    @State private var photo: PhotosPickerItem?
    @State private var data: Data?
    @State private var lines: [RecognizedLine] = []
    @State private var error = ""
    @State private var busy = false
    @State private var camera = false
    @State private var page = 0
    var body: some View {
        VStack(spacing: 12) {
            Text("\(store.source) → \(store.target)").font(.headline)
            HStack { PhotosPicker("Choose photo", selection: $photo, matching: .images); if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo") { camera = true } } }
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160) }
            if busy { ProgressView("Reading prices…") }
            ForEach(Array(lines.dropFirst(page*4).prefix(4))) { line in
                VStack(alignment: .leading) { Text(line.text).font(.subheadline); Text(convert(line.text)).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if lines.count > 4 { HStack { Button("Previous") { page -= 1 }.disabled(page == 0); Spacer(); Button("Next") { page += 1 }.disabled((page+1)*4 >= lines.count) } }
            Text(error).font(.caption).foregroundStyle(.red)
            Text("Review recognized prices. Bare numbers may be quantities; the selected source currency is assumed. Live camera overlays are not yet implemented.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding().navigationTitle("Photo prices").navigationBarTitleDisplayMode(.inline)
        .onChange(of: photo) { _, item in Task { do { if let raw = try await item?.loadTransferable(type: Data.self) { await recognize(raw) } } catch { self.error = error.localizedDescription } } }
        .sheet(isPresented: $camera) { ConversionCamera { image in camera = false; if let image, let raw = ConversionPhoto.jpeg(from: image) { Task { await recognize(raw) } } } }
    }
    private func recognize(_ raw: Data) async {
        guard let sanitized = ConversionPhoto.jpeg(from: raw) else { error = "Couldn’t read that image."; return }
        data = sanitized; busy = true; error = ""; defer { busy = false }
        do { lines = try await ImageText.read(sanitized); page = 0; if lines.isEmpty { error = "No text found. Try a clearer photo." } } catch { self.error = error.localizedDescription }
    }
    private func convert(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\d+(?:,\d{3})*(?:\.\d{1,2})?"#) else { return "" }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: text), let value = Decimal(string: String(text[range]).replacingOccurrences(of: ",", with: "")) else { return nil }
            guard let rate = store.source == store.target ? Decimal(1) : store.snapshot?.multiplier(from: store.source, to: store.target) else { return "Rate unavailable" }
            return "≈ " + Currency.named(store.target).symbol + " " + Amount.format(value * rate, currency: .named(store.target))
        }.joined(separator: " · ")
    }
}
struct TripTranslateView: View {
    @EnvironmentObject private var trip: TripStore
    @State private var photo: PhotosPickerItem?
    @State private var image: Data?
    @State private var input = ""
    @State private var output = ""
    @State private var note = ""
    @State private var source = "ja"
    @State private var target = "en"
    @State private var config: TranslationSession.Configuration?
    @State private var message = ""
    @State private var saved = false
    private let languages = ["en", "ja", "es", "fr", "de", "ko", "zh-Hans", "it", "pt"]
    var body: some View {
        VStack(spacing: 12) {
            HStack { Picker("From", selection: $source) { ForEach(languages, id: \.self) { Text(Locale.current.localizedString(forIdentifier: $0) ?? $0).tag($0) } }; Image(systemName: "arrow.right"); Picker("To", selection: $target) { ForEach(languages, id: \.self) { Text(Locale.current.localizedString(forIdentifier: $0) ?? $0).tag($0) } } }
            PhotosPicker("Choose image", selection: $photo, matching: .images)
            if let image, let ui = UIImage(data: image) { Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 100) }
            TextField("Enter or scan text", text: $input, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            Button("Translate") { output = ""; message = "Translating…"; let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target)); if config == next { config?.invalidate() } else { config = next } }.disabled(input.isEmpty)
            TextField("Translation", text: $output, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            TextField("Notes about this image or translation", text: $note, axis: .vertical).lineLimit(1...2).textFieldStyle(.roundedBorder)
            HStack { Button("Save translation") { if trip.saveTranslation(TranslationRecord(text: output, note: note, image: image)) { message = "Saved on this device" } }.disabled(output.isEmpty && image == nil); Spacer(); Button("Saved") { saved = true } }
            Text(message).font(.caption).accessibilityAddTraits(.updatesFrequently)
            Spacer(minLength: 0)
        }.padding().navigationBarTitleDisplayMode(.inline)
        .translationTask(config) { session in do { let response = try await session.translate(input); output = response.targetText; message = "" } catch { message = error.localizedDescription } }
        .onChange(of: photo) { _, item in Task { do { if let raw = try await item?.loadTransferable(type: Data.self), let cleaned = ConversionPhoto.jpeg(from: raw) { image = cleaned; input = try await ImageText.read(cleaned).map(\.text).joined(separator: "\n"); output = "" } } catch { message = error.localizedDescription } } }
        .sheet(isPresented: $saved) { NavigationStack { List(trip.translations) { record in NavigationLink { SavedTranslationEditor(record: record) } label: { VStack(alignment: .leading) { Text(record.text.isEmpty ? "Saved image" : record.text).lineLimit(2); Text(record.note).font(.caption) } } }.navigationTitle("Saved translations").toolbar { Button("Done") { saved = false } } } }
    }
}
struct SavedTranslationEditor: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State var record: TranslationRecord
    var body: some View { VStack(spacing: 16) { if let data = record.image, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }; Text("Translation"); TextEditor(text: $record.text).frame(height: 120); Text("Notes"); TextEditor(text: $record.note).frame(height: 90); Button("Save changes") { if trip.saveTranslation(record) { dismiss() } }; Spacer() }.padding().navigationTitle("Saved translation") }
}
