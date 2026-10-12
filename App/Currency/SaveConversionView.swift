import SwiftUI
import PhotosUI
import AVFoundation

struct SaveConversionView: View {
    let draft: SavedConversion
    var initialPhoto: Data? = nil
    @ObservedObject var saved: SavedConversions
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var photo: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var loadingPhoto = false
    @State private var showsCamera = false
    @State private var error: String?
    @State private var saving = false
    @State private var loadedInitialPhoto = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Spotted something you might buy? Save its converted price with a photo and note, then revisit it later. Handy for travel finds and souvenirs.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Preview") {
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                            .accessibilityLabel("Photo that will be saved")
                    }
                    LabeledContent("Original", value: Amount.format(draft.amount, currency: .named(draft.source)) + " " + draft.source)
                    LabeledContent("Converted", value: Amount.format(draft.convertedAmount, currency: .named(draft.target)) + " " + draft.target)
                    if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text(note).font(.subheadline).textSelection(.enabled) }
                    Text("This amount and rate will stay as saved.").font(.caption).foregroundStyle(.secondary)
                    if !draft.rateDates.isEmpty {
                        Text("Rates dated \(draft.rateDates.joined(separator: " / "))").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Note (optional)") {
                    TextField("What is it? Where did you find it?", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .onChange(of: note) { _, value in if value.count > 2000 { note = String(value.prefix(2000)) } }
                }
                Section("Photo (optional)") {
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                            .accessibilityLabel("Photo attached to this conversion")
                        Button("Remove photo", role: .destructive) { self.photo = nil; selectedPhoto = nil }
                    }
                    if loadingPhoto { ProgressView("Loading photo…") }
                    Button { Task { await openCamera() } } label: { Label("Take photo", systemImage: "camera") }
                        .disabled(loadingPhoto || !UIImagePickerController.isSourceTypeAvailable(.camera))
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }.disabled(loadingPhoto)
                }
                Section { Text("Saved on this iPhone. Available offline after saving.").font(.caption).foregroundStyle(.secondary) }
            }
            .onAppear { if !loadedInitialPhoto { photo = initialPhoto; loadedInitialPhoto = true } }
            .navigationTitle("Save conversion").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } }.tripToolbarBackground()
                ToolbarItem(placement: .confirmationAction) { TripActionButton("Save", primary: true) { save() }.disabled(loadingPhoto || saving || saved.loadError != nil) }.tripToolbarBackground()
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                loadingPhoto = true
                defer { loadingPhoto = false }
                do {
                    guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                    let encoded = await Task.detached(priority: .userInitiated) { ConversionPhoto.jpeg(from: data) }.value
                    guard !Task.isCancelled else { return }
                    guard let encoded else { throw CocoaError(.fileReadCorruptFile) }
                    photo = encoded
                } catch {
                    if !Task.isCancelled { self.error = "Couldn’t load that photo. Try another image or download it from iCloud first." }
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                ConversionCamera { image in
                    showsCamera = false
                    if let image {
                        if let encoded = ConversionPhoto.jpeg(from: image) { photo = encoded }
                        else { error = "Couldn’t attach this photo. Please try again." }
                    }
                }.ignoresSafeArea()
            }
            .alert("Couldn’t complete action", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    @MainActor private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        else { allowed = status == .authorized }
        if allowed { showsCamera = true }
        else { error = "Camera access is disabled. Enable it for Simple Currency in Settings, or choose a photo from Photos." }
    }

    private func save() {
        saving = true
        defer { saving = false }
        var entry = draft
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try saved.save(entry, photo: photo); dismiss() }
        catch { self.error = "Couldn’t save this conversion. Your note and photo are still here. Check available storage and try again." }
    }
}

struct SavedConversionsView: View {
    @ObservedObject var saved: SavedConversions
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let error = saved.loadError { ContentUnavailableView("Saved items unavailable", systemImage: "exclamationmark.triangle", description: Text(error)) }
                else if saved.items.isEmpty { ContentUnavailableView("No saved conversions", systemImage: "bookmark", description: Text("Save a conversion with a note or photo to remember something you found.")) }
                else {
                    List { ForEach(saved.items) { item in
                        NavigationLink {
                            SavedConversionDetail(item: item, photoURL: saved.photoURL(for: item))
                        } label: {
                            HStack(spacing: 12) {
                                if let url = saved.photoURL(for: item) {
                                    TripPhotoThumbnail(id: "price-" + item.id.uuidString, url: url, size: 60)
                                }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.summary).font(.subheadline.weight(.semibold))
                                    if !item.note.isEmpty { Text(item.note).font(.subheadline).lineLimit(2) }
                                    Text(item.savedAt, format: .dateTime.month().day().year()).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }.onDelete { saved.remove(at: $0) }
                    }
                }
            }.safeAreaInset(edge: .bottom) {
                if saved.canUndo || saved.actionError != nil {
                    VStack(alignment: .leading) {
                        if let error = saved.actionError { Text(error).font(.caption).foregroundStyle(.red) }
                        if saved.canUndo {
                            HStack { Text("Conversion deleted").font(.subheadline); Spacer(); Button("Undo") { saved.undoDelete() }.buttonStyle(TripButtonStyle()) }
                        }
                    }.padding().background(Color(.secondarySystemBackground))
                }
            }.navigationTitle("Saved conversions")
                .toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Done") { dismiss() } }.tripToolbarBackground() }
        }
    }
}

private struct SavedConversionDetail: View {
    let item: SavedConversion
    let photoURL: URL?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(item.summary).font(.title2.weight(.semibold)).textSelection(.enabled)
                Text("Saved \(item.savedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                if let photoURL, let image = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityLabel("Saved item photo")
                } else if item.photoFilename != nil { Label("Photo unavailable", systemImage: "photo") }
                if !item.note.isEmpty { Text(item.note).textSelection(.enabled) }
                if !item.rateDates.isEmpty { Text("Rates dated \(item.rateDates.joined(separator: " / "))").font(.caption).foregroundStyle(.secondary) }
                if let checked = item.ratesCheckedAt { Text("Rates checked \(checked.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                Text("Original saved estimate. Bank and card rates may differ.").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }.navigationTitle("Saved conversion").navigationBarTitleDisplayMode(.inline)
    }
}


#if DEBUG
extension SaveConversionView {
    init(tutorialDraft draft: SavedConversion, photo: Data, saved: SavedConversions) {
        self.init(draft: draft, initialPhoto: photo, saved: saved)
        _note = State(initialValue: draft.note)
    }
}
enum TutorialSavedViews {
    static func detail(_ item: SavedConversion, photoURL: URL?) -> some View {
        NavigationStack { SavedConversionDetail(item: item, photoURL: photoURL) }
    }
}
#endif
