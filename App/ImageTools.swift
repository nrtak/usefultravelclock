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
    @State private var prices: [RecognizedPrice] = []
    @State private var error = ""
    @State private var busy = false
    @State private var camera = false
    @State private var live = true
    @State private var page = 0
    @State private var pricesHeld = false
    @State private var scanID = UUID()
    @State private var includeUnmarked = false
    var body: some View {
        VStack(spacing: 12) {
            CurrencyPairControl(store: store)
            Toggle("Include unmarked numbers", isOn: $includeUnmarked).font(.subheadline)
            HStack(spacing: 16) {
                priceModeButton("Live Camera", icon: "camera.viewfinder", selected: live) {
                    guard !live else { return }
                    live = true; data = nil; prices = []; page = 0
                    pricesHeld = false; scanID = UUID(); error = ""
                }
                priceModeButton("Photo", icon: "photo", selected: !live) {
                    live = false; error = ""
                }
            }
            if live { LiveTextCamera(onText: captureLivePrices, onError: { error = $0 }).id(scanID).frame(height: 240).clipShape(RoundedRectangle(cornerRadius: 14)) }
            if !live {
                HStack(spacing: 20) {
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo", systemImage: "photo.on.rectangle") }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { camera = true } label: { Label("Take photo", systemImage: "camera") }
                    }
                }.buttonStyle(.bordered)
            }
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160) }
            if live {
                HStack {
                    Text(pricesHeld ? "Prices held" : "Point at prices").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { prices = []; page = 0; pricesHeld = false; scanID = UUID() } label: {
                        Label("Scan again", systemImage: "arrow.clockwise")
                    }.disabled(!pricesHeld)
                }
            }
            if busy { ProgressView("Reading prices…") }
            ForEach(Array(prices.dropFirst(page*4).prefix(4))) { price in
                VStack(alignment: .leading) { Text(Currency.named(store.source).symbol + " " + Amount.format(price.value, currency: .named(store.source))).font(.subheadline); Text(convert(price.value)).font(.headline) }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if prices.count > 4 { HStack { Button("Previous") { page -= 1 }.disabled(page == 0); Spacer(); Button("Next") { page += 1 }.disabled((page+1)*4 >= prices.count) } }
            Text(error).font(.caption).foregroundStyle(.red)
            Text(includeUnmarked ? "Unmarked numbers use the From currency. Check for product IDs or quantities. Prices stay until you scan again." : "Only marked prices are read. Prices stay until you scan again. Check the currency and values.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding().navigationTitle("Photo prices").navigationBarTitleDisplayMode(.inline)
        .onChange(of: includeUnmarked) { _, _ in
            prices = []; page = 0; pricesHeld = false; scanID = UUID()
            if !live, let data { Task { await recognize(data) } }
        }
        .onChange(of: photo) { _, item in Task { do { if let raw = try await item?.loadTransferable(type: Data.self) { await recognize(raw) } } catch { self.error = error.localizedDescription } } }
        .sheet(isPresented: $camera) { ConversionCamera { image in camera = false; if let image, let raw = ConversionPhoto.jpeg(from: image) { Task { await recognize(raw) } } } }
    }
    private func priceModeButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(selected ? Color.white : Color.blue)
            .background(selected ? Color.blue : Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue, lineWidth: selected ? 0 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func captureLivePrices(_ text: String) {
        guard !pricesHeld else { return }
        let captured = PriceRecognition.read(text, currency: .named(store.source), includeUnmarked: includeUnmarked)
        guard !captured.isEmpty else { return }
        prices = captured
        page = 0
        pricesHeld = true
    }
    private func recognize(_ raw: Data) async {
        guard let sanitized = ConversionPhoto.jpeg(from: raw) else { error = "Couldn’t read that image."; return }
        live = false; data = sanitized; busy = true; error = ""; defer { busy = false }
        do {
            let text = try await ImageText.read(sanitized).map(\.text).joined(separator: "\n")
            prices = PriceRecognition.read(text, currency: .named(store.source), includeUnmarked: includeUnmarked)
            page = 0
            if prices.isEmpty { error = "No marked prices found. Include a currency symbol, code or price label in the photo." }
        } catch { self.error = error.localizedDescription }
    }
    private func convert(_ value: Decimal) -> String {
        guard let rate = store.source == store.target ? Decimal(1) : store.snapshot?.multiplier(from: store.source, to: store.target) else { return "Rate unavailable" }
        return "≈ " + Currency.named(store.target).symbol + " " + Amount.format(value * rate, currency: .named(store.target))
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
    @State private var languageSide: TranslationLanguageSide?
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
                        languageButton("From", selection: $source, side: .source)
                        Button {
                            let previous = source; source = target; target = previous
                        } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 36, height: 44) }
                            .buttonStyle(.plain).accessibilityLabel("Swap languages")
                        languageButton("To", selection: $target, side: .target)
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
                    .buttonStyle(.borderedProminent).disabled(input.isEmpty || Locale.Language(identifier: source).isEquivalent(to: Locale.Language(identifier: target)))
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
        .sheet(item: $languageSide) { side in
            TranslationLanguagePicker(selection: side == .source ? $source : $target, title: side == .source ? "From language" : "To language")
        }
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
    private func languageButton(_ role: String, selection: Binding<String>, side: TranslationLanguageSide) -> some View {
        Button { languageSide = side } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(role).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(Locale.current.localizedString(forIdentifier: selection.wrappedValue) ?? selection.wrappedValue)
                        .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "magnifyingglass").font(.body)
                }
            }.padding(10).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
        .accessibilityLabel("\(role) language: \(Locale.current.localizedString(forIdentifier: selection.wrappedValue) ?? selection.wrappedValue)")
        .accessibilityHint("Search supported languages")
    }

}
struct SavedTranslationEditor: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State var record: TranslationRecord
    var body: some View { VStack(spacing: 16) { if let data = record.image, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180) }; Text("Translation"); TextEditor(text: $record.text).frame(height: 120); Text("Notes"); TextEditor(text: $record.note).frame(height: 90); Spacer() }.padding().navigationTitle("Saved translation").toolbar { ToolbarItem(placement: .confirmationAction) { TripActionButton("Save", primary: true) { if trip.saveTranslation(record) { dismiss() } } } } }
}
