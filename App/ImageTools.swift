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
    @State private var live = true
    @State private var page = 0
    var body: some View {
        VStack(spacing: 12) {
            CurrencyPairControl(store: store)
            Picker("Mode", selection: $live) { Text("Live camera").tag(true); Text("Photo").tag(false) }.pickerStyle(.segmented)
            if live { LiveTextCamera(onText: { text in lines = text.split(separator: "\n").map { RecognizedLine(text: String($0)) }; page = 0 }, onError: { error = $0 }).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 14)) }
            HStack { PhotosPicker("Choose photo", selection: $photo, matching: .images); if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo") { camera = true } } }
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160) }
            if busy { ProgressView("Reading prices…") }
            ForEach(Array(lines.dropFirst(page*4).prefix(4))) { line in
                VStack(alignment: .leading) { Text(line.text).font(.subheadline); Text(convert(line.text)).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if lines.count > 4 { HStack { Button("Previous") { page -= 1 }.disabled(page == 0); Spacer(); Button("Next") { page += 1 }.disabled((page+1)*4 >= lines.count) } }
            Text(error).font(.caption).foregroundStyle(.red)
            Text("Prices update as the camera reads text. Check the selected source currency and recognized values.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding().navigationTitle("Photo prices").navigationBarTitleDisplayMode(.inline)
        .onChange(of: photo) { _, item in Task { do { if let raw = try await item?.loadTransferable(type: Data.self) { await recognize(raw) } } catch { self.error = error.localizedDescription } } }
        .sheet(isPresented: $camera) { ConversionCamera { image in camera = false; if let image, let raw = ConversionPhoto.jpeg(from: image) { Task { await recognize(raw) } } } }
    }
    private func recognize(_ raw: Data) async {
        guard let sanitized = ConversionPhoto.jpeg(from: raw) else { error = "Couldn’t read that image."; return }
        live = false; data = sanitized; busy = true; error = ""; defer { busy = false }
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
    @State private var liveTranslation = false
    @State private var liveText = ""
    private let languages = ["en", "ja", "es", "fr", "de", "ko", "zh-Hans", "it", "pt"]
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    HStack {
                        Label("Languages", systemImage: "character.bubble").font(.headline)
                        Spacer()
                        Button { saved = true } label: { Label("Saved", systemImage: "bookmark") }
                    }
                    HStack {
                        languageMenu("From", selection: $source)
                        Image(systemName: "arrow.right")
                        languageMenu("To", selection: $target)
                    }
                }.tripPanel()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button { liveTranslation = false } label: { Label("Text", systemImage: "text.alignleft") }
                            .buttonStyle(.bordered).tint(liveTranslation ? .gray : .blue)
                        Button { liveTranslation.toggle() } label: { Label("Live camera", systemImage: "camera.viewfinder") }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel(liveTranslation ? "Stop live camera translation" : "Start live camera translation")
                        Spacer(minLength: 0)
                        PhotosPicker(selection: $photo, matching: .images) { Image(systemName: "photo").frame(width: 44, height: 44) }
                            .accessibilityLabel("Choose photo to translate")
                    }
                    if liveTranslation {
                        LiveTextCamera(onText: { liveText = $0 }, onError: { message = $0 }).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 14))
                        Text("Translates as you point the camera at text.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let image, let ui = UIImage(data: image) { Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 100) }
                    TextField("Enter text, or choose a photo to read it", text: $input, axis: .vertical).lineLimit(3...5).textFieldStyle(.roundedBorder)
                    Button {
                        output = ""; message = "Translating…"
                        let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
                        if config == next { config?.invalidate() } else { config = next }
                    } label: { Label("Translate", systemImage: "arrow.right").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).disabled(input.isEmpty)
                }.tripPanel()
                VStack(alignment: .leading, spacing: 10) {
                    Label("Translation", systemImage: "character.bubble.fill").font(.headline)
                    TextField("Your translation appears here", text: $output, axis: .vertical).lineLimit(3...5).textFieldStyle(.roundedBorder)
                    TextField("Notes (optional)", text: $note, axis: .vertical).lineLimit(1...2).textFieldStyle(.roundedBorder)
                }.tripPanel()
                if !message.isEmpty { Text(message).font(.caption).accessibilityAddTraits(.updatesFrequently) }
                TripArtwork(symbol: "character.bubble")
            }.padding(12)
        }.scrollBounceBehavior(.basedOnSize).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            TripActionButton("Save", primary: true) { if trip.saveTranslation(TranslationRecord(text: output, note: note, image: image)) { message = "Saved on this device" } }.disabled(output.isEmpty && image == nil)
        } }
        .task(id: liveText) {
            guard liveTranslation else { return }
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            guard !Task.isCancelled else { return }
            input = liveText
            if liveText.isEmpty { output = ""; return }
            let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
            if config == next { config?.invalidate() } else { config = next }
        }
        .onChange(of: liveTranslation) { _, _ in liveText = ""; output = "" }
        .onChange(of: source) { _, _ in config = nil; output = ""; liveText = "" }
        .onChange(of: target) { _, _ in config = nil; output = ""; liveText = "" }
        .translationTask(config) { session in
            let requested = input
            do { let response = try await session.translate(requested); if requested == input { output = response.targetText; message = "" } } catch { message = error.localizedDescription }
        }
        .onChange(of: photo) { _, item in Task { do { if let raw = try await item?.loadTransferable(type: Data.self), let cleaned = ConversionPhoto.jpeg(from: raw) { liveTranslation = false; image = cleaned; input = try await ImageText.read(cleaned).map(\.text).joined(separator: "\n"); output = "" } } catch { message = error.localizedDescription } } }
        .sheet(isPresented: $saved) { NavigationStack { List(trip.translations) { record in NavigationLink { SavedTranslationEditor(record: record) } label: { VStack(alignment: .leading) { Text(record.text.isEmpty ? "Saved image" : record.text).lineLimit(2); Text(record.note).font(.caption) } } }.navigationTitle("Saved translations").toolbar { Button("Done") { saved = false } } } }
    }
    private func languageMenu(_ role: String, selection: Binding<String>) -> some View {
        Menu {
            ForEach(languages, id: \.self) { language in
                Button { selection.wrappedValue = language } label: {
                    if selection.wrappedValue == language {
                        Label(Locale.current.localizedString(forIdentifier: language) ?? language, systemImage: "checkmark")
                    } else {
                        Text(Locale.current.localizedString(forIdentifier: language) ?? language)
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(role).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(Locale.current.localizedString(forIdentifier: selection.wrappedValue) ?? selection.wrappedValue)
                        .font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.caption2).fixedSize()
                }
            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.accessibilityLabel("\(role) language: \(Locale.current.localizedString(forIdentifier: selection.wrappedValue) ?? selection.wrappedValue)")
    }

}
struct SavedTranslationEditor: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State var record: TranslationRecord
    var body: some View { VStack(spacing: 16) { if let data = record.image, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }; Text("Translation"); TextEditor(text: $record.text).frame(height: 120); Text("Notes"); TextEditor(text: $record.note).frame(height: 90); Spacer() }.padding().navigationTitle("Saved translation").toolbar { ToolbarItem(placement: .confirmationAction) { TripActionButton("Save", primary: true) { if trip.saveTranslation(record) { dismiss() } } } } }
}
