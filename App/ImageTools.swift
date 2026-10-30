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
    @State private var photoRevision = UUID()
    @State private var busy = false
    @State private var live = true
    @State private var page = 0
    @State private var pricesHeld = false
    @State private var scanID = UUID()
    @State private var includeUnmarked = false
    @State private var editingPrice: RecognizedPrice?
    @State private var choosesPhoto = false
    @State private var captureID: UUID?
    @State private var capturingPhoto = false
    @State private var scanningPaused = false
    @ObservedObject var savedPrices: SavedConversions
    @State private var priceDraft: SavedConversion?
    @State private var showsSavedPrices = false
    @State private var referencePhoto: Data?
    @State private var noPriceFound = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                content(cameraHeight: max(240, min(360, geometry.size.height * 0.46)), pageSize: geometry.size.height < 650 ? 2 : 4)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .sheet(item: $editingPrice) { price in
            PriceCorrectionView(price: price, currency: .named(store.source)) { text in
                guard let corrected = PriceRecognition.correcting(prices, id: price.id, text: text) else { return false }
                prices = corrected
                return true
            }
        }
    }
    private func content(cameraHeight: CGFloat, pageSize: Int) -> some View {
        VStack(spacing: 10) {
            CurrencyPairControl(store: store)
            Toggle("Include unmarked numbers", isOn: $includeUnmarked).font(.subheadline)
            HStack(spacing: 8) {
                priceModeButton("Live Camera", icon: "camera.viewfinder", selected: live) {
                    photoRevision = UUID(); photo = nil; busy = false; live = true; data = nil; prices = []; page = 0
                    pricesHeld = false; scanID = UUID(); error = ""
                    captureID = nil; capturingPhoto = false; referencePhoto = nil; noPriceFound = false
                    scanningPaused = false
                }
                priceModeButton("Photo", icon: "photo", selected: !live) {
                    photo = nil; choosesPhoto = true
                }
            }
            .photosPicker(isPresented: $choosesPhoto, selection: $photo, matching: .images)
            SavedConversionNotice(saved: savedPrices) { showsSavedPrices = true }
            if live {
                LiveTextCamera(covered: choosesPhoto || showsSavedPrices || priceDraft != nil || editingPrice != nil, recognitionEnabled: live && !pricesHeld && !scanningPaused && !busy, onText: captureLivePrices, onError: { error = $0; capturingPhoto = false }, resetID: scanID, captureID: captureID, onPhoto: { image in
                    let manualCapture = capturingPhoto
                    capturingPhoto = false
                    guard let raw = ConversionPhoto.jpeg(from: image) else { error = "Couldn’t read that photo."; return }
                    referencePhoto = raw
                    if manualCapture { Task { await recognize(raw) } }
                }).frame(height: cameraHeight).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottom) {
                        Button { capturingPhoto = true; captureID = UUID() } label: {
                            ZStack {
                                Circle().fill(.white).frame(width: 54, height: 54)
                                Circle().stroke(.black.opacity(0.35), lineWidth: 2).frame(width: 44, height: 44)
                                if capturingPhoto { ProgressView().tint(.black) }
                                else { Image(systemName: "camera.fill").foregroundStyle(.black) }
                            }.frame(width: 64, height: 64).contentShape(Circle())
                        }.buttonStyle(.plain).disabled(capturingPhoto).accessibilityLabel("Take photo of prices")
                            .padding(.bottom, 8)
                    }
            }
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
                Label("Photo captured", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
            }
            if live {
                HStack {
                    Text(capturingPhoto ? "Capturing photo…" : scanningPaused ? "Paused" : pricesHeld ? "Prices held" : "Scanning for prices…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        scanningPaused.toggle()
                        if !scanningPaused { prices = []; page = 0; pricesHeld = false; captureID = nil; scanID = UUID() }
                    } label: { Label(scanningPaused ? "Resume" : "Pause", systemImage: scanningPaused ? "play.fill" : "pause.fill") }
                        .font(.caption).frame(minHeight: 44).disabled(capturingPhoto)
                    Button { prices = []; page = 0; pricesHeld = false; scanningPaused = false; captureID = nil; capturingPhoto = false; referencePhoto = nil; scanID = UUID() } label: {
                        Label("Scan again", systemImage: "arrow.clockwise")
                    }.disabled(!pricesHeld)
                }
            }
            if busy { ProgressView("Reading prices…") }
            ForEach(Array(prices.dropFirst(page * pageSize).prefix(pageSize))) { price in
                Button { editingPrice = price } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Currency.named(store.source).symbol + " " + Amount.format(price.value, currency: .named(store.source))).font(.subheadline)
                            Text(convert(price.value)).font(.headline)
                        }
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(.blue)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).accessibilityLabel("Edit recognized price " + Amount.format(price.value, currency: .named(store.source)))
            }
            if !prices.isEmpty { Text("Tap a price to correct it.").font(.caption2).foregroundStyle(.secondary) }
            if prices.count > pageSize { HStack { Button("Previous") { page -= 1 }.disabled(page == 0); Spacer(); Button("Next") { page += 1 }.disabled((page+1)*pageSize >= prices.count) } }
            if !prices.isEmpty {
                ForEach(Array(prices.dropFirst(page * pageSize).prefix(pageSize))) { price in
                    Button { preparePriceSave(price.value) } label: {
                        Label("Save " + Currency.named(store.source).symbol + " " + Amount.format(price.value, currency: .named(store.source)), systemImage: "bookmark")
                    }.tripButtonStyle().disabled(live && referencePhoto == nil)
                }
            }
            if live && prices.isEmpty && noPriceFound && !scanningPaused {
                Text("No prices found yet. Move closer to a currency symbol or choose Photo.").font(.caption).foregroundStyle(.secondary)
            }
            TripRateStatus(store: store).font(.caption2).foregroundStyle(.secondary)
            if let checked = store.lastChecked { Text(checked).font(.caption2).foregroundStyle(.secondary) }
            Text(error).font(.caption).foregroundStyle(.red)
            Text(includeUnmarked ? "Unmarked numbers use the From currency. Check for product IDs or quantities. Prices stay until you scan again." : "Only marked prices are read. Prices stay until you scan again. Check the currency and values.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding().navigationTitle("Photo prices").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsSavedPrices) { SavedConversionsView(saved: savedPrices) }
        .sheet(item: $priceDraft) { draft in SaveConversionView(draft: draft, initialPhoto: referencePhoto ?? data, saved: savedPrices) }
        .task(id: scanID) {
            noPriceFound = false
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            if live && prices.isEmpty { noPriceFound = true }
        }
        .onChange(of: pageSize) { _, _ in page = 0 }
        .onChange(of: includeUnmarked) { _, _ in
            prices = []; page = 0; pricesHeld = false; captureID = nil; capturingPhoto = false; scanID = UUID()
            if !live, let data { Task { await recognize(data) } }
        }
        .task(id: photo) {
            guard let selected = photo else { return }
            let revision = UUID(); photoRevision = revision; busy = false
            do {
                if let raw = try await selected.loadTransferable(type: Data.self), !Task.isCancelled, photoRevision == revision {
                    await recognize(raw, revision: revision)
                }
            } catch { if !Task.isCancelled && photoRevision == revision { self.error = error.localizedDescription } }
        }
        .onDisappear { photoRevision = UUID(); busy = false }
    }
    private func priceModeButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(selected ? Color.white : Color.blue)
            .background(selected ? Color.blue : Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue, lineWidth: selected ? 0 : 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { if selected { Image(systemName: "checkmark.circle.fill").font(.caption).padding(5).accessibilityHidden(true) } }
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func captureLivePrices(_ text: String) {
        guard live && !pricesHeld && !scanningPaused && !busy else { return }
        let captured = PriceRecognition.read(text, currency: .named(store.source), includeUnmarked: includeUnmarked)
        guard !captured.isEmpty else { return }
        prices = captured
        page = 0
        pricesHeld = true
        referencePhoto = nil; captureID = UUID()
    }
    private func recognize(_ raw: Data, revision suppliedRevision: UUID? = nil) async {
        let revision = suppliedRevision ?? UUID()
        photoRevision = revision
        guard let sanitized = ConversionPhoto.jpeg(from: raw) else { error = "Couldn’t read that image."; return }
        live = false; data = sanitized; busy = true; error = ""; defer { if photoRevision == revision { busy = false } }
        do {
            let text = try await ImageText.read(sanitized).map(\.text).joined(separator: "\n")
            guard !Task.isCancelled, photoRevision == revision else { return }
            prices = PriceRecognition.read(text, currency: .named(store.source), includeUnmarked: includeUnmarked)
            page = 0
            if prices.isEmpty { error = "No marked prices found. Include a currency symbol, code or price label in the photo." }
        } catch { if !Task.isCancelled && photoRevision == revision { self.error = error.localizedDescription } }
    }
    private func preparePriceSave(_ value: Decimal) {
        guard let rate = store.source == store.target ? Decimal(1) : store.snapshot?.multiplier(from: store.source, to: store.target) else {
            error = "Rate unavailable. Return to Conversions and refresh rates."; return
        }
        priceDraft = SavedConversion(id: UUID(), savedAt: Date(), source: store.source, target: store.target,
            amount: value, multiplier: rate, convertedAmount: value * rate,
            rateDates: store.source == store.target ? [] : store.snapshot?.dates(from: store.source, to: store.target) ?? [],
            ratesCheckedAt: store.snapshot?.fetchedAt, note: "", photoFilename: nil)
    }
    private func convert(_ value: Decimal) -> String {
        guard let rate = store.source == store.target ? Decimal(1) : store.snapshot?.multiplier(from: store.source, to: store.target) else { return "Rate unavailable" }
        return "≈ " + Currency.named(store.target).symbol + " " + Amount.format(value * rate, currency: .named(store.target))
    }
}
struct TripTranslateView: View {
    var onClose: (() -> Void)? = nil
    @State private var choosingTranslationPhoto = false
    @State private var leavingTranslation = false
    private var translationCovered: Bool { choosingTranslationPhoto || saved || languageSide != nil || leavingTranslation }
    @State private var savedTranslationID: UUID?
    private var hasUnsavedTranslation: Bool {
        (!input.isEmpty || !output.isEmpty || !note.isEmpty || image != nil) && savedTranslationID != translationSaveID
    }
    @discardableResult
    private func saveCurrentTranslation() -> Bool {
        if trip.saveTranslation(TranslationRecord(id: translationSaveID, text: output, note: note, image: image)) {
            savedTranslationID = translationSaveID
            message = "Saved on this iPhone"
            return true
        }
        message = trip.error ?? "Could not save. Keep this screen open and tap Save to retry."
        return false
    }
    @EnvironmentObject private var trip: TripStore
    @State private var translationSaveID = UUID()
    @State private var photo: PhotosPickerItem?
    @State private var image: Data?
    @State private var input = ""
    @State private var output = ""
    @State private var note = ""
    @AppStorage("trip-translation-source") private var source = "ja"
    @AppStorage("trip-translation-target") private var target = "en"
    @State private var config: TranslationSession.Configuration?
    @State private var preparationConfig: TranslationSession.Configuration?
    @State private var languageStatus = "Checking offline languages…"
    @ObservedObject private var connection = TripConnectionStore.shared
    @State private var message = ""
    @State private var saved = false
    @State private var liveTranslation = false
    @State private var liveText = ""
    @State private var livePaused = false
    @State private var liveCaptureID: UUID?
    @State private var liveScanID = UUID()
    @State private var keepingPhoto = false
    @State private var noTextFound = false
    @State private var languageSide: TranslationLanguageSide?
    private var translationContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    HStack {
                        TripSectionLabel(title: "Languages", symbol: "character.bubble", color: .purple)
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
                    Text(languageStatus).font(.caption).foregroundStyle(.secondary)
                    Button("Prepare for offline use", systemImage: "arrow.down.circle") {
                        let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
                        if preparationConfig == next { preparationConfig?.invalidate() } else { preparationConfig = next }
                    }.font(.caption).disabled(connection.isOffline || Locale.Language(identifier: source).isEquivalent(to: Locale.Language(identifier: target)))
                }.tripPanel()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        translationModeButton("Text", icon: "text.alignleft", selected: !liveTranslation && image == nil) { photo = nil; liveScanID = UUID(); keepingPhoto = false; liveTranslation = false; image = nil }
                        translationModeButton("Live camera", icon: "camera.viewfinder", selected: liveTranslation) { photo = nil; resetTranslationScan(); liveTranslation = true }
                        Spacer(minLength: 0)
                        Button { choosingTranslationPhoto = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                Text("Photo").font(.caption)
                                if !liveTranslation && image != nil { Image(systemName: "checkmark.circle.fill").accessibilityHidden(true) }
                            }.frame(minWidth: 72, minHeight: 48).contentShape(Rectangle())
                        }
                            .buttonStyle(.plain)
                            .photosPicker(isPresented: $choosingTranslationPhoto, selection: $photo, matching: .images)
                            .accessibilityLabel("Choose photo to translate")
                            .accessibilityAddTraits(!liveTranslation && image != nil ? .isSelected : [])
                            .accessibilityValue(!liveTranslation && image != nil ? "Selected" : "Not selected")
                    }
                    if liveTranslation {
                        LiveTextCamera(covered: translationCovered, recognitionEnabled: liveTranslation && !livePaused && !keepingPhoto, onText: { if liveTranslation && !livePaused { liveText = $0 } }, onError: { message = $0; keepingPhoto = false }, resetID: liveScanID, captureID: liveCaptureID, onPhoto: { photo in
                            keepingPhoto = false
                            guard let captured = ConversionPhoto.jpeg(from: photo) else { message = "Couldn’t keep photo. Tap Scan again to retry."; return }
                            image = captured; livePaused = true; output = ""; message = "Reading photo…"
                            let generation = liveScanID
                            Task {
                                do {
                                    let recognized = try await ImageText.read(captured).map(\.text).joined(separator: "\n")
                                    guard generation == liveScanID && liveTranslation else { return }
                                    input = recognized
                                    if input.isEmpty { message = "No text found. Move closer or try another photo."; return }
                                    let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
                                    if config == next { config?.invalidate() } else { config = next }
                                } catch { if generation == liveScanID && liveTranslation { message = "Couldn’t read photo. Tap Scan again to retry." } }
                            }
                        }).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .bottom) {
                                Button { keepingPhoto = true; liveCaptureID = UUID() } label: {
                                    Image(systemName: "camera.fill").foregroundStyle(.black).frame(width: 56, height: 56).background(.white, in: Circle())
                                }.buttonStyle(.plain).padding(8).disabled(keepingPhoto).accessibilityLabel("Capture translation photo")
                            }
                        HStack {
                            Text(keepingPhoto ? "Keeping photo…" : livePaused ? "Paused · results held" : noTextFound && liveText.isEmpty ? "No text found · move closer" : "Scanning for text…").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(livePaused ? "Resume" : "Pause", systemImage: livePaused ? "play.fill" : "pause.fill") {
                                if livePaused { resetTranslationScan() }
                                else { keepingPhoto = true; liveCaptureID = UUID(); livePaused = true }
                            }.font(.caption).frame(minHeight: 44).disabled(keepingPhoto)
                            Button("Scan again", systemImage: "arrow.clockwise") { resetTranslationScan() }.font(.caption).frame(minHeight: 44).disabled(keepingPhoto)
                        }
                        Text("Translates as you point the camera at text.").font(.caption).foregroundStyle(.secondary)
                    }
                    if let image, let ui = UIImage(data: image) { Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 100) }
                    TextField("Enter text, or choose a photo to read it", text: $input, axis: .vertical).lineLimit(3...5).textFieldStyle(.roundedBorder).accessibilityLabel("Text to translate")
                    Button {
                        output = ""; message = "Translating…"
                        let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
                        if config == next { config?.invalidate() } else { config = next }
                    } label: { Label("Translate", systemImage: "arrow.right").frame(maxWidth: .infinity) }
                    .tripButtonStyle(primary: true).disabled(input.isEmpty || Locale.Language(identifier: source).isEquivalent(to: Locale.Language(identifier: target)))
                }.tripPanel()
                VStack(alignment: .leading, spacing: 10) {
                    TripSectionLabel(title: "Translation", symbol: "character.bubble.fill", color: .purple)
                    TextField("Your translation appears here", text: $output, axis: .vertical).lineLimit(3...5).textFieldStyle(.roundedBorder).accessibilityLabel("Translation result, editable")
                    TextField("Notes (optional)", text: $note, axis: .vertical).lineLimit(1...2).textFieldStyle(.roundedBorder)
                }.tripPanel()
                if !message.isEmpty { Text(message).font(.caption).accessibilityAddTraits(.updatesFrequently) }
                if !liveTranslation { TripArtwork(symbol: "character.bubble") }
            }.padding(12)
        }.scrollBounceBehavior(.basedOnSize).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) {
            TripActionButton("Save", primary: true) { saveCurrentTranslation() }.disabled(output.isEmpty && image == nil)
        }.tripToolbarBackground() }
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { if hasUnsavedTranslation { leavingTranslation = true } else { onClose() } }
                }
            }
        }
        .interactiveDismissDisabled(onClose != nil && hasUnsavedTranslation)
        .confirmationDialog("Save before closing?", isPresented: $leavingTranslation, titleVisibility: .visible) {
            if !output.isEmpty || image != nil {
                Button("Save and close") { if saveCurrentTranslation() { onClose?() } }
            }
            Button("Discard and close", role: .destructive) { onClose?() }
            Button("Keep editing", role: .cancel) { }
        }
        .onChange(of: input) { _, _ in translationSaveID = UUID() }
        .onChange(of: output) { _, _ in translationSaveID = UUID() }
        .onChange(of: note) { _, _ in translationSaveID = UUID() }
        .onChange(of: image) { _, _ in translationSaveID = UUID() }
        .sheet(item: $languageSide) { side in
            TranslationLanguagePicker(selection: side == .source ? $source : $target, title: side == .source ? "From language" : "To language")
        }
    }
    var body: some View {
        translationContent
        .task(id: liveScanID) {
            noTextFound = false
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            if liveTranslation && liveText.isEmpty { noTextFound = true }
        }
        .task(id: liveText) {
            guard liveTranslation && !livePaused && !translationCovered else { return }
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            guard !Task.isCancelled, !translationCovered else { return }
            input = liveText
            if liveText.isEmpty { output = ""; return }
            let next = TranslationSession.Configuration(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
            if config == next { config?.invalidate() } else { config = next }
        }
        .onChange(of: translationCovered) { _, covered in if covered { config = nil } }
        .onChange(of: liveTranslation) { _, active in
            liveText = ""; message = ""; livePaused = false
            if active { resetTranslationScan() }
        }
        .onChange(of: source) { _, _ in config = nil; preparationConfig = nil; output = ""; liveText = "" }
        .onChange(of: target) { _, _ in config = nil; preparationConfig = nil; output = ""; liveText = "" }
        .task(id: source + "|" + target) { await checkOfflineLanguages() }
        .translationTask(preparationConfig) { session in
            let selectedSource = source, selectedTarget = target
            do {
                try await session.prepareTranslation()
                guard !Task.isCancelled, selectedSource == source, selectedTarget == target else { return }
                await checkOfflineLanguages()
            } catch {
                guard !Task.isCancelled, selectedSource == source, selectedTarget == target else { return }
                message = "Languages were not prepared. Connect and try Prepare for offline use again."
            }
        }
        .translationTask(config) { session in await translate(using: session) }
        .task(id: photo) {
            guard let selected = photo else { return }
            let generation = liveScanID
            do {
                guard let raw = try await selected.loadTransferable(type: Data.self), !Task.isCancelled,
                      generation == liveScanID, let cleaned = ConversionPhoto.jpeg(from: raw) else { return }
                let recognized = try await ImageText.read(cleaned).map(\.text).joined(separator: "\n")
                guard !Task.isCancelled, generation == liveScanID else { return }
                liveTranslation = false; image = cleaned; input = recognized; output = ""
                message = input.isEmpty ? "No text found. Choose a clearer photo or enter text." : "Photo ready · tap Translate"
            } catch { if !Task.isCancelled && generation == liveScanID { message = error.localizedDescription } }
        }
        .onDisappear { liveScanID = UUID(); keepingPhoto = false }
        .sheet(isPresented: $saved) { SavedTranslationsView() }
    }
    private func translate(using session: TranslationSession) async {
            let requested = input
            let requestedSource = source, requestedTarget = target
            do {
                let status = await LanguageAvailability().status(from: Locale.Language(identifier: requestedSource), to: Locale.Language(identifier: requestedTarget))
                guard !Task.isCancelled else { return }
                if connection.isOffline && status != .installed {
                    message = "Offline · these languages are not downloaded. Prepare them while connected. Saved translations are still available."
                    return
                }
                let response = try await session.translate(requested)
                if !Task.isCancelled && requested == input && requestedSource == source && requestedTarget == target {
                    output = response.targetText; message = ""; await checkOfflineLanguages()
                }
            } catch {
                if !Task.isCancelled && requested == input && requestedSource == source && requestedTarget == target {
                    message = error.localizedDescription
                }
            }
    }
    private func checkOfflineLanguages() async {
        let from = source, to = target
        let status = await LanguageAvailability().status(from: Locale.Language(identifier: from), to: Locale.Language(identifier: to))
        guard !Task.isCancelled, from == source, to == target else { return }
        switch status {
        case .installed: languageStatus = "Languages downloaded · ready offline"
        case .supported: languageStatus = "Language download needed · prepare while online"
        case .unsupported: languageStatus = "This language pair is unavailable"
        @unknown default: languageStatus = "Offline language availability unknown"
        }
    }
    private func resetTranslationScan() {
        livePaused = false; liveText = ""; image = nil; input = ""; output = ""; message = ""
        keepingPhoto = false; liveCaptureID = nil; liveScanID = UUID(); config = nil
    }
    private func translationModeButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 12).frame(minHeight: 48)
                .foregroundStyle(selected ? Color.white : Color.blue)
                .background(selected ? Color.blue : Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: selected ? 0 : 1.5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityValue(selected ? "Selected" : "Not selected")
    }
    private func languageButton(_ role: String, selection: Binding<String>, side: TranslationLanguageSide) -> some View {
        Button { languageSide = side } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(role).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(TranslationLanguageLabel.name(selection.wrappedValue))
                        .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "magnifyingglass").font(.body)
                }
            }.padding(10).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
        .accessibilityLabel("\(role) language: \(TranslationLanguageLabel.name(selection.wrappedValue))")
        .accessibilityHint("Search supported languages")
    }

}
struct SavedTranslationEditor: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State var record: TranslationRecord
    @State private var deleting = false
    @State private var original: TranslationRecord?
    @State private var leaving = false
    private var hasChanges: Bool {
        guard let original else { return false }
        return original.title != record.title || original.text != record.text || original.note != record.note
    }
    var body: some View {
        Form {
            Section("Title") { TextField("Optional title", text: Binding(get: { record.title ?? "" }, set: { record.title = $0 })) }
            if let data = record.image, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).accessibilityLabel("Saved reference photo") }
            Section("Translation") { TextEditor(text: $record.text).frame(minHeight: 150).accessibilityLabel("Saved translation text") }
            Section("Notes") { TextEditor(text: $record.note).frame(minHeight: 100).accessibilityLabel("Translation notes") }
            if let error = trip.error { Section { Text(error).foregroundStyle(.red); Button("Retry save") { save() } } }
            Section { Button("Delete translation", role: .destructive) { deleting = true } }
        }.navigationTitle("Saved translation")
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled(hasChanges)
            .onAppear { if original == nil { original = record } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { if hasChanges { leaving = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { TripActionButton("Save", primary: true) { save() } }.tripToolbarBackground()
            }
            .confirmationDialog("Save your changes before leaving?", isPresented: $leaving, titleVisibility: .visible) {
                Button("Save changes") { save() }
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) { }
            }
            .confirmationDialog("Delete this saved translation?", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete translation", role: .destructive) { if trip.deleteTranslation(record.id) { dismiss() } }
            } message: { Text("Undo is available in Saved translations while the app remains open.") }
    }
    private func save() { if trip.saveTranslation(record) { dismiss() } }
}


#if DEBUG
extension PriceImageView {
    init(tutorialStore store: ConverterStore, saved: SavedConversions, photo: Data, held: Bool) {
        self.init(store: store, savedPrices: saved)
        _prices = State(initialValue: held ? [RecognizedPrice(value: 500), RecognizedPrice(value: 400), RecognizedPrice(value: 650)] : [])
        _pricesHeld = State(initialValue: held)
        _referencePhoto = State(initialValue: held ? photo : nil)
    }
}
extension TripTranslateView {
    init(tutorialPhoto: Data?, completed: Bool) {
        self.init()
        _image = State(initialValue: tutorialPhoto)
        _input = State(initialValue: "出口\n切符売り場")
        _output = State(initialValue: completed ? "Exit\nTicket office" : "")
        _note = State(initialValue: completed ? "Station directions · example" : "")
    }
}
#endif
