import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct TripDocumentsView: View {
    @EnvironmentObject private var trip: TripStore
    @State private var query = ""
    @State private var traveler = ""
    @State private var adding = false
    @State private var cleanup = false
    @State private var error: String?
    @State private var discardDraft = false
    @State private var sort = "Date"
    @State private var unassignedOnly = false
    private var filtered: [TripDocument] {
        trip.documents.filter { document in
            let record = trip.records.first { $0.id == document.recordID }
            return document.matches(query, record: record) && (traveler.isEmpty || document.traveler == traveler) && (!unassignedOnly || record == nil)
        }.sorted { a, b in
            switch sort {
            case "Trip":
                let first = trip.records.first { $0.id == a.recordID }?.name ?? "Unassigned"
                let second = trip.records.first { $0.id == b.recordID }?.name ?? "Unassigned"
                if first != second { return first.localizedStandardCompare(second) == .orderedAscending }
            case "Type": if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
            default: break
            }
            if a.updatedAt != b.updatedAt { return a.updatedAt > b.updatedAt }
            return a.id.uuidString < b.id.uuidString
        }
    }
    private var completed: [TripDocument] {
        trip.documents.filter { doc in trip.records.contains { $0.id == doc.recordID && $0.end < Date() } }
    }
    var body: some View {
        List {
            Section {
                Picker("Sort documents", selection: $sort) { ForEach(["Date", "Trip", "Type"], id: \.self) { Text($0).tag($0) } }
                Toggle("Unassigned documents only", isOn: $unassignedOnly)
                if trip.importDraft != nil {
                    Button { adding = true } label: { Label("Resume document import", systemImage: "arrow.clockwise") }
                    Button("Discard import draft", role: .destructive) { discardDraft = true }
                }
                Button { adding = true } label: { Label("Add document", systemImage: "plus.circle") }
                LabeledContent("Stored on this iPhone", value: ByteCountFormatter.string(fromByteCount: Int64(trip.documentBytes), countStyle: .file))
                if !completed.isEmpty {
                    Button("Remove completed-trip documents…", role: .destructive) { cleanup = true }
                }
                let travelers = Array(Set(trip.documents.map(\.traveler).filter { !$0.isEmpty })).sorted()
                if !travelers.isEmpty {
                    Picker("Traveler", selection: $traveler) {
                        Text("Everyone").tag("")
                        ForEach(travelers, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            if filtered.isEmpty {
                ContentUnavailableView(trip.documents.isEmpty ? "Keep tickets handy offline" : "No matching documents", systemImage: "doc", description: Text(trip.documents.isEmpty ? "Tap Add document to save a ticket or confirmation from Files or Photos." : "Change the search or filters to find your saved documents."))
                if !trip.documents.isEmpty { Button("Clear search and filters") { query = ""; traveler = ""; unassignedOnly = false } }
            }
            ForEach(filtered) { document in
                NavigationLink { TripDocumentDetail(documentID: document.id) } label: {
                    TripDocumentRow(document: document, record: trip.records.first { $0.id == document.recordID }, available: trip.documentAvailable(document))
                }
            }
        }
        .searchable(text: $query, prompt: "Name, airline, hotel, traveler or note")
        .navigationTitle("Documents").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $adding) { TripDocumentImport(recordID: nil) }
        .confirmationDialog("Discard the unfinished document import?", isPresented: $discardDraft, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { do { try trip.discardImportDraft() } catch { self.error = TripSaveError.message(error) } }
        } message: { Text("Documents already saved in Trip Info stay available.") }
        .confirmationDialog("Remove \(completed.count) documents from completed trips?", isPresented: $cleanup, titleVisibility: .visible) {
            Button("Remove documents", role: .destructive) {
                do { try trip.removeDocuments(Set(completed.map(\.id))) } catch { self.error = TripSaveError.message(error) }
            }
        } message: { Text("This removes the copies in Trip Info. Your original files and trip details stay unchanged.") }
        .alert("Couldn’t update documents", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}

struct TripDocumentRow: View {
    let document: TripDocument
    let record: TravelRecord?
    let available: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.kind == .boardingPass ? "airplane" : document.fileExtension == "pdf" ? "doc.richtext" : "photo").foregroundStyle(.blue).font(.title2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name).font(.headline)
                Text([document.kind.rawValue, record?.name ?? "Unassigned", document.traveler].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                Label(available ? "Available offline" : "Import again", systemImage: available ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.caption).foregroundStyle(available ? Color.secondary : Color.orange)
            }
        }.padding(.vertical, 3).accessibilityElement(children: .combine)
    }
}

struct TripRecordDocuments: View {
    @EnvironmentObject private var trip: TripStore
    let recordID: UUID
    @State private var adding = false
    var body: some View {
        Section("Documents") {
            ForEach(trip.documents(for: recordID)) { document in
                NavigationLink { TripDocumentDetail(documentID: document.id) } label: {
                    TripDocumentRow(document: document, record: trip.records.first { $0.id == recordID }, available: trip.documentAvailable(document))
                }
            }
            Button { adding = true } label: { Label("Add document", systemImage: "plus.circle") }
        }.sheet(isPresented: $adding) { TripDocumentImport(recordID: recordID) }
    }
}

struct TripDocumentDetail: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    let documentID: UUID
    @State private var editing = false
    @State private var replacing = false
    @State private var removing = false
    @State private var preview: TripPreviewFile?
    @State private var share: TripPreviewFile?
    @State private var error: String?
    private var document: TripDocument? { trip.documents.first { $0.id == documentID } }
    var body: some View {
        Group {
            if let document {
                List {
                    Section {
                        Button { open(document, sharing: false) } label: { Label("Open original", systemImage: "doc.viewfinder") }
                            .disabled(!trip.documentAvailable(document))
                        Label(trip.documentAvailable(document) ? "Available offline" : "Original copy missing — replace this document", systemImage: trip.documentAvailable(document) ? "checkmark.circle" : "exclamationmark.circle").font(.caption).foregroundStyle(.secondary)
                        LabeledContent("Type", value: document.kind.rawValue)
                        LabeledContent("Traveler", value: document.traveler.isEmpty ? "Not labeled" : document.traveler)
                        LabeledContent("Trip", value: trip.records.first { $0.id == document.recordID }?.name ?? "Unassigned")
                        LabeledContent("Original file", value: document.originalFilename)
                        LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(document.byteCount), countStyle: .file))
                        Text("Added or replaced \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        if !document.note.isEmpty { Text(document.note).textSelection(.enabled) }
                    }
                    Section {
                        Button("Edit labels, note & trip") { editing = true }
                        Button("Replace document") { replacing = true }
                        Button { open(document, sharing: true) } label: { Label("Share or save to Files", systemImage: "square.and.arrow.up") }.disabled(!trip.documentAvailable(document))
                        Button("Delete document", role: .destructive) { removing = true }
                    }
                }.navigationTitle(document.name).navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $editing) { TripDocumentLabels(document: document) }
                .sheet(isPresented: $replacing) { TripDocumentImport(recordID: document.recordID, replacing: document) }
            } else { ContentUnavailableView("Document unavailable", systemImage: "doc") }
        }
        .sheet(item: $preview, onDismiss: { trip.clearDocumentPreviews() }) { file in TripDocumentPreviewSheet(url: file.url) }
        .sheet(item: $share, onDismiss: { trip.clearDocumentPreviews() }) { file in TripDocumentShare(url: file.url).modifier(TripDocumentPrivacyMask()) }
        .confirmationDialog("Delete this document?", isPresented: $removing, titleVisibility: .visible) {
            Button("Delete document", role: .destructive) {
                do { try trip.removeDocuments([documentID]); dismiss() } catch { self.error = TripSaveError.message(error) }
            }
        } message: { Text("Only the copy in Trip Info is removed.") }
        .alert("Couldn’t open document", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
        .onChange(of: phase) { _, value in if value == .background { preview = nil; share = nil; trip.clearDocumentPreviews() } }
        .onChange(of: trip.unlocked) { _, value in if !value { preview = nil; share = nil; dismiss() } }
    }
    private func open(_ document: TripDocument, sharing: Bool) {
        do {
            let file = TripPreviewFile(url: try trip.previewURL(document))
            if sharing { share = file } else { preview = file }
        } catch { self.error = TripSaveError.message(error) }
    }
}

struct TripDocumentLabels: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State var document: TripDocument
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                TripDocumentFields(name: $document.name, kind: $document.kind, traveler: $document.traveler, note: $document.note, recordID: $document.recordID)
                if let error { Text(error).foregroundStyle(.red).font(.caption) }
            }.navigationTitle("Document details").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    do { try trip.updateDocument(document); dismiss() } catch { self.error = TripSaveError.message(error) }
                }.disabled(document.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !trip.unlocked) }
            }
        }.modifier(TripDocumentPrivacyMask()).onChange(of: trip.unlocked) { _, value in if !value { dismiss() } }
        .onAppear { if !trip.records.contains(where: { $0.id == document.recordID }) { document.recordID = nil } }
    }
}

struct TripDocumentFields: View {
    @EnvironmentObject private var trip: TripStore
    @Binding var name: String
    @Binding var kind: TripDocumentKind
    @Binding var traveler: String
    @Binding var note: String
    @Binding var recordID: UUID?
    var body: some View {
        Section("Details") {
            TextField("Document name", text: $name)
            Picker("Type", selection: $kind) { ForEach(TripDocumentKind.allCases) { Text($0.rawValue).tag($0) } }
            TextField("Traveler (optional)", text: $traveler).textContentType(.name)
            Picker("Trip", selection: $recordID) {
                Text("Unassigned").tag(Optional<UUID>.none)
                ForEach(trip.records.sorted { $0.start < $1.start }) { record in
                    Text((record.name.isEmpty ? record.kind : record.name) + " · " + record.start.formatted(date: .abbreviated, time: .omitted)).tag(Optional(record.id))
                }
            }
            TextField("Note (optional)", text: $note, axis: .vertical).lineLimit(2...5)
        }
    }
}

struct TripDocumentImport: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State var recordID: UUID?
    var replacing: TripDocument? = nil
    var incomingURL: URL? = nil
    var onPreserved: (() -> Void)? = nil
    @State private var payload: TripDocumentPayload?
    @State private var files = false
    @State private var photo: PhotosPickerItem?
    @State private var busy = false
    @State private var name = ""
    @State private var kind = TripDocumentKind.other
    @State private var traveler = ""
    @State private var note = ""
    @State private var recognized = ""
    @State private var recognitionDone = false
    @State private var bookingReference = ""
    @State private var error: String?
    @State private var operation = UUID()
    @State private var storageID = UUID()
    @State private var replacementID: UUID?
    @State private var savedDocumentID: UUID?
    @State private var restored = false
    @State private var draftTask: Task<Void, Never>?
    @State private var finished = false
    @State private var blockedByExistingDraft = false
    @State private var recoveringDraftPayload = false
    private var draftValue: TripImportDraft {
        TripImportDraft(storageID: storageID, recordID: recordID, replacingID: replacementID, savedDocumentID: savedDocumentID, name: name, kind: kind, traveler: traveler, note: note, bookingReference: bookingReference, recognized: recognized, recognitionDone: recognitionDone)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { files = true } label: { Label("Choose from Files", systemImage: "folder") }
                    PhotosPicker(selection: $photo, matching: .images, preferredItemEncoding: .current) { Label("Choose from Photos", systemImage: "photo") }
                    if let payload {
                        Text(payload.filename).font(.subheadline)
                        Label(savedDocumentID != nil ? "Document saved · booking reference needs attention" : (trip.importDraft?.storageID == storageID ? "Import draft encrypted on this iPhone" : "Import draft not saved yet"), systemImage: "iphone").font(.caption).foregroundStyle(.secondary)
                    } else { Text("PDFs and images · up to 25 MB per document").font(.caption).foregroundStyle(.secondary) }
                    if busy { ProgressView("Preparing document…") }
                }.disabled(busy)
                if payload != nil {
                    TripDocumentFields(name: $name, kind: $kind, traveler: $traveler, note: $note, recordID: $recordID)
                    Section("Read details") {
                        Button { recognize() } label: { Label("Read text on this iPhone", systemImage: "text.viewfinder") }.disabled(busy)
                        Text("Review recognized text before using it. Nothing is filled in automatically.").font(.caption).foregroundStyle(.secondary)
                        if recognitionDone {
                            if recognized.isEmpty { Text("No readable text found. You can still save the original.").font(.caption) }
                            else {
                                TextEditor(text: $recognized).frame(minHeight: 140).accessibilityLabel("Recognized document text")
                                Button("Use text as note") { note = recognized }
                            }
                        }
                        if recordID != nil { TextField("Booking reference to save to trip (optional)", text: $bookingReference).textInputAutocapitalization(.characters).autocorrectionDisabled() }
                    }
                }
                if let error { Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                    if savedDocumentID != nil { Button("Retry booking reference") { save() }; Button("Keep document and finish") { finish() } }
                    else if let payload { Button("Retry preserving import draft") {
                        busy = true
                        Task {
                            do { try await trip.prepareImportDraft(draftValue, payload: payload); onPreserved?(); self.error = nil }
                            catch { self.error = TripSaveError.message(error) }
                            busy = false
                        }
                    }.disabled(busy) }
                } }
            }.disabled(busy || blockedByExistingDraft).navigationTitle(replacementID == nil ? "Add document" : "Replace document").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button(savedDocumentID == nil ? "Save" : "Retry") { save() }.disabled(payload == nil || busy || !trip.unlocked || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .interactiveDismissDisabled(busy)
            .fileImporter(isPresented: $files, allowedContentTypes: [.pdf, .image]) { result in
                switch result { case .success(let url): prepare(url); case .failure(let failure): error = failure.localizedDescription }
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                busy = true; error = nil
                let revision = UUID(); operation = revision
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw TripDocumentError.invalidFile }
                        let value = try await Task.detached { try TripDocumentPayload.validate(data, filename: "Photo") }.value
                        guard operation == revision, trip.unlocked else { return }
                        await accept(value)
                    } catch { if operation == revision { self.error = TripSaveError.message(error) } }
                    if operation == revision { busy = false }
                }
            }
            .onAppear {
                guard !restored else { return }; restored = true
                replacementID = replacing?.id
                if let draft = trip.importDraft,
                   !draft.canResume(replacing: replacing?.id, hasIncomingFile: incomingURL != nil) {
                    blockedByExistingDraft = true
                    error = "Finish or discard your unfinished import in Documents before starting another. Its file and notes have been kept."
                    return
                }
                if incomingURL == nil, let draft = trip.importDraft, replacing == nil || draft.replacingID == replacing?.id {
                    storageID = draft.storageID; recordID = draft.recordID; replacementID = draft.replacingID; savedDocumentID = draft.savedDocumentID ?? trip.documents.first { $0.id == draft.storageID }?.id
                    name = draft.name; kind = draft.kind; traveler = draft.traveler; note = draft.note; bookingReference = draft.bookingReference
                    recognized = draft.recognized ?? ""; recognitionDone = draft.recognitionDone ?? false
                    do {
                        payload = try trip.importDraftPayload()
                        if savedDocumentID != nil { error = "Document already saved. Retry the booking reference or keep the document and finish." }
                    } catch {
                        recoveringDraftPayload = true
                        self.error = "The import’s labels and notes were kept. Choose the original file again: " + TripSaveError.message(error)
                    }
                    return
                }
                if let replacing { name = replacing.name; kind = replacing.kind; traveler = replacing.traveler; note = replacing.note }
                else { traveler = trip.records.first { $0.id == recordID }?.traveler ?? "" }
                if let incomingURL { prepare(incomingURL) }
            }
            .onChange(of: draftValue) { _, _ in
                draftTask?.cancel()
                guard !busy else { return }
                draftTask = Task { @MainActor in
                    do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                    guard !Task.isCancelled else { return }; persistDraft()
                }
            }
            .onChange(of: phase) { _, value in if value == .inactive { draftTask?.cancel(); if !busy { persistDraft() } } }
            .onChange(of: trip.unlocked) { _, value in if !value { operation = UUID(); payload = nil; recognized = ""; dismiss() } }
            .onDisappear { draftTask?.cancel(); if !busy && !finished { persistDraft() }; operation = UUID(); busy = false }
        }.modifier(TripDocumentPrivacyMask())
    }
    private func prepare(_ url: URL) {
        busy = true; error = nil
        let revision = UUID(); operation = revision
        Task {
            do {
                let value = try await Task.detached { try TripDocumentPayload.read(url) }.value
                guard operation == revision, trip.unlocked else { return }
                await accept(value)
            }
            catch { if operation == revision { self.error = TripSaveError.message(error) } }
            if operation == revision { busy = false }
        }
    }
    private func accept(_ value: TripDocumentPayload) async {
        guard trip.unlocked else { return }
        let previousDefaultName = payload.map { URL(fileURLWithPath: $0.filename).deletingPathExtension().lastPathComponent }
        let replaceDefaultName = name.isEmpty || name == previousDefaultName
        payload = value
        if !recoveringDraftPayload { recognized = ""; recognitionDone = false; bookingReference = "" }
        recoveringDraftPayload = false
        if let savedDocumentID, trip.documents.contains(where: { $0.id == savedDocumentID }) {
            replacementID = savedDocumentID
        }
        storageID = UUID(); savedDocumentID = nil
        if replacing == nil && replaceDefaultName { name = URL(fileURLWithPath: value.filename).deletingPathExtension().lastPathComponent }
        do { try await trip.prepareImportDraft(draftValue, payload: value); onPreserved?() }
        catch { self.error = "Could not save the import draft. Keep this screen open and retry: " + TripSaveError.message(error) }
    }
    private func recognize() {
        guard let payload else { return }
        busy = true; error = nil
        let revision = UUID(); operation = revision
        Task {
            do {
                let text = try await Task.detached { try payload.recognizedText() }.value
                if operation == revision, trip.unlocked { recognized = text; recognitionDone = true }
            } catch { if operation == revision { self.error = TripSaveError.message(error) } }
            if operation == revision { busy = false }
        }
    }
    private func save() {
        guard let payload else { return }
        draftTask?.cancel()
        do {
            if savedDocumentID == nil {
                let document = try trip.importDocument(payload, name: name, kind: kind, traveler: traveler, note: note, recordID: recordID, replacing: replacementID, idempotencyID: storageID)
                savedDocumentID = document.id
                persistDraft()
            } else if let id = savedDocumentID {
                guard var document = trip.documents.first(where: { $0.id == id }) else { error = "The saved document is no longer available. Choose the original again to import it."; return }
                document.recordID = recordID; document.name = name; document.kind = kind; document.traveler = traveler; document.note = note
                try trip.updateDocument(document)
            }
            if !bookingReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard var record = trip.records.first(where: { $0.id == recordID }) else { error = "Document saved. Choose an existing trip to save the booking reference, or keep the document and finish."; return }
                record.bookingReference = bookingReference.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trip.save(record, clearDraft: false) { error = "Document saved. Booking reference could not be saved: " + (trip.error ?? "Retry saving."); return }
                if var draft = trip.drafts.first(where: { $0.id == record.id }) {
                    draft.bookingReference = record.bookingReference
                    if !trip.saveDraft(draft) { error = "Document and reference saved, but the unfinished trip draft could not be updated. Retry before finishing."; return }
                }
            }
            finish()
        } catch { self.error = TripSaveError.message(error) }
    }
    private func persistDraft() {
        guard payload != nil, trip.unlocked else { return }
        do { try trip.saveImportDraft(draftValue, payload: trip.importDraft?.storageID == storageID ? nil : payload); onPreserved?() }
        catch { self.error = "Could not preserve the import draft: " + TripSaveError.message(error) }
    }
    private func finish() {
        draftTask?.cancel()
        do { try trip.discardImportDraft(); finished = true; dismiss() }
        catch { self.error = "Document saved. Could not clear the import draft: " + TripSaveError.message(error) }
    }
}

struct TripPreviewFile: Identifiable { let id = UUID(); let url: URL }
struct TripOriginalPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
struct TripDocumentShare: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct TripDocumentPrivacyMask: ViewModifier {
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.overlay {
            if phase != .active {
                Color(.systemBackground).ignoresSafeArea().overlay(Label("Trip Info", systemImage: "lock.fill").font(.title2))
            }
        }
    }
}

struct TripDocumentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    var body: some View {
        NavigationStack {
            TripOriginalPreview(url: url)
                .navigationTitle(url.deletingPathExtension().lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.modifier(TripDocumentPrivacyMask())
    }
}
