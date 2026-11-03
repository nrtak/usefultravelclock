import SwiftUI
import UIKit

struct TravelRecordsView: View {
    var currency: ConverterStore? = nil
    var cities: [City] = []
    var acceptsIncomingDocuments = true
    @EnvironmentObject private var trip: TripStore
    @EnvironmentObject private var inbox: TripDocumentInbox
    @Environment(\.scenePhase) private var phase
    @State private var draft: TravelRecord?
    @State private var preview: TripPreviewFile?
    @State private var incoming: TripPreviewFile?
    @State private var incomingSource: URL?
    @State private var incomingPreserved = false
    @State private var visible = false
    @State private var query = ""
    @State private var discard: TravelRecord?
    private var nextDocument: TripDocument? {
        trip.summaryDocument(at: Date())
    }
    private var entries: [TravelRecord] { trip.records.filter { $0.matches(query) }.sorted { $0.start < $1.start } }
    var body: some View {
        Group {
            if !trip.unlocked {
                VStack(spacing: 16) {
                    if trip.loading { ProgressView("Loading travel details…") }
                    else {
                        ContentUnavailableView("Travel details unavailable", systemImage: "suitcase", description: Text("Retry loading your saved details."))
                        Button("Retry") { Task { await trip.unlock() } }.buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    if query.isEmpty {
                        Section("Trip essentials") {
                            NavigationLink { TripDocumentsView() } label: { Label("Documents", systemImage: "folder") }
                            if inbox.url != nil, trip.importDraft != nil {
                                Text("Finish or discard your current document draft in Documents before importing the next file.").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let currency {
                                NavigationLink { TripReadinessView(currency: currency, cities: cities) } label: { Label("Before you leave", systemImage: "checklist") }
                            }
                        }
                    }
                    if query.isEmpty && !trip.records.isEmpty {
                        Section("Today & next") {
                            let next = TripSummary.record(in: trip.records, at: Date())
                            if let next {
                            Button { draft = trip.drafts.first { $0.id == next.id } ?? next } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(next.timingLabel(at: Date())).font(.subheadline)
                                    Text(next.name.isEmpty ? next.kind : next.name).font(.headline)
                                    Text(next.timeLabel(start: next.start > Date())).font(.subheadline)
                                }.foregroundStyle(.primary)
                            }
                            }
                            let today = trip.records.filter { Calendar.current.isDateInToday($0.start) && $0.id != next?.id }.sorted { $0.start < $1.start }
                            ForEach(today) { record in
                                Button { draft = trip.drafts.first { $0.id == record.id } ?? record } label: {
                                    Text((record.name.isEmpty ? record.kind : record.name) + " · " + record.timingLabel(at: Date()))
                                }
                            }
                            if next == nil && today.isEmpty { Text("No upcoming bookings. Add your next trip when you’re ready.").foregroundStyle(.secondary) }
                            Text("Today follows your iPhone’s calendar date. Booking times show each location’s time zone.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if !trip.drafts.isEmpty {
                        Section("Unfinished edits") {
                            ForEach(trip.drafts) { saved in
                                Button { draft = saved } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label("Resume " + (saved.name.isEmpty ? saved.kind : saved.name), systemImage: "square.and.pencil")
                                        if let date = saved.draftSavedAt { Text("Saved " + date.formatted(date: .abbreviated, time: .shortened)).font(.subheadline).foregroundStyle(.secondary) }
                                    }
                                }.accessibilityHint("Continue editing this saved draft")
                                    .swipeActions { Button("Discard", role: .destructive) { discard = saved } }
                                    .accessibilityAction(named: "Discard draft") { discard = saved }
                            }
                            Text("Drafts are encrypted on this iPhone. Swipe a draft to discard it.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if let document = nextDocument {
                        Section("Next trip document") {
                            Button {
                                do { preview = TripPreviewFile(url: try trip.previewURL(document)) } catch { trip.error = error.localizedDescription }
                            } label: { TripDocumentRow(document: document, record: trip.records.first { $0.id == document.recordID }, available: trip.documentAvailable(document)) }
                        }
                    }
                    Section {
                        Button { draft = TravelRecord() } label: {
                            Label("Add travel entry", systemImage: "plus.circle.fill").frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    if entries.isEmpty {
                        ContentUnavailableView(query.isEmpty ? "No travel entries" : "No matching trips", systemImage: "suitcase", description: Text(query.isEmpty ? "Add a hotel, flight or transport booking." : "Search by name, route, traveler, booking reference or note."))
                    }
                    ForEach(entries) { record in
                        Button { draft = trip.drafts.first { $0.id == record.id } ?? record } label: {
                            HStack(spacing: 14) {
                                    Image(systemName: record.kind == "Hotel" ? "bed.double" : record.kind == "Flight" ? "airplane" : "tram")
                                    .font(.title2).foregroundStyle(.orange).frame(width: 32).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.name.isEmpty ? record.kind : record.name).font(.headline)
                                    Text(record.timingLabel(at: Date())).font(.subheadline).foregroundStyle(.secondary)
                                    Text((record.kind == "Hotel" ? "Check-in · " : "Departure · ") + record.timeLabel(start: true)).font(.subheadline)
                                    Text((record.kind == "Hotel" ? "Check-out · " : "Arrival · ") + record.timeLabel(start: false)).font(.subheadline).foregroundStyle(.secondary)
                                    if !record.reference.isEmpty { Text(record.reference).font(.subheadline) }
                                    if !record.from.isEmpty { Text(record.from + (record.to.isEmpty ? "" : " → " + record.to)).font(.subheadline).lineLimit(2) }
                                }
                            }.foregroundStyle(Color.primary).padding(.vertical, 4)
                        }.buttonStyle(.plain).accessibilityElement(children: .combine).accessibilityHint("Edit travel details and view attached documents")
                        .contextMenu {
                            ForEach(trip.documents(for: record.id)) { document in
                                Button("Open " + document.name, systemImage: "doc.viewfinder") {
                                    do { preview = TripPreviewFile(url: try trip.previewURL(document)) }
                                    catch { trip.error = TripSaveError.message(error) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Name, route, traveler, reference or note")
        .confirmationDialog("Discard these unfinished edits?", isPresented: Binding(get: { discard != nil }, set: { if !$0 { discard = nil } }), titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { if let discard { _ = trip.discardDraft(discard.id) }; discard = nil }
        } message: { Text("Saved trip details remain available.") }

        .sheet(item: $draft, onDismiss: receiveDocument) { record in RecordEditor(record: record) }
        .sheet(item: $preview, onDismiss: { trip.clearDocumentPreviews(); receiveDocument() }) { file in TripDocumentPreviewSheet(url: file.url) }
        .sheet(item: $incoming, onDismiss: finishIncoming) { file in
            TripDocumentImport(recordID: nil, incomingURL: file.url, onPreserved: {
                if incomingSource == file.url { incomingPreserved = true; inbox.markPreserved(file.url) }
            })
        }
        .onAppear { visible = true; receiveDocument() }
        .onDisappear { visible = false }
        .onChange(of: trip.importDraft?.storageID) { _, _ in receiveDocument() }
        .onChange(of: acceptsIncomingDocuments) { _, accepts in if accepts { receiveDocument() } }
        .onChange(of: inbox.url) { _, _ in receiveDocument() }
        .onChange(of: trip.unlocked) { _, value in if value { receiveDocument() } else { preview = nil; incoming = nil } }
        .onChange(of: phase) { _, value in if value == .background { preview = nil; trip.clearDocumentPreviews() } }
    }
    private func receiveDocument() {
        guard visible, acceptsIncomingDocuments, phase == .active, trip.unlocked else { return }
        // App lock can recreate this screen after an import was preserved. Don't
        // import its original URL again when the encrypted draft is recoverable.
        if incomingSource == nil, inbox.currentPreserved { inbox.finishCurrent() }
        guard let url = inbox.url, trip.importDraft == nil, incomingSource == nil, incoming == nil, draft == nil, preview == nil else { return }
        incomingSource = url; incomingPreserved = false
        incoming = TripPreviewFile(url: url)
    }
    private func finishIncoming() {
        if let incomingSource {
            inbox.finishCurrent(ifMatching: incomingSource, preserved: incomingPreserved,
                                interrupted: phase != .active || !trip.unlocked)
        }
        incomingSource = nil; incomingPreserved = false
        receiveDocument()
    }
}

struct RecordEditor: View {
    @Environment(\.dismiss) private var dismiss
    var record: TravelRecord
    var body: some View {
        NavigationStack {
            RecordForm(record: record, onSave: { dismiss() })
                .navigationTitle("Travel details").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { TripNavigationButton(title: "Back") { dismiss() } }.tripToolbarBackground() }
        }
    }
}

struct RecordForm: View {
    @EnvironmentObject private var trip: TripStore
    @State var record: TravelRecord
    var onSave: (() -> Void)? = nil
    @State private var choosingStart: Bool?
    @State private var deleting = false
    @State private var copied = false
    @State private var saving = false
    @State private var draftStatus = ""
    @State private var draftTask: Task<Void, Never>?
    @State private var completed = false
    @Environment(\.scenePhase) private var phase
    private var hasDetails: Bool {
        [record.name, record.reference, record.from, record.to, record.note, record.traveler ?? "", record.bookingReference ?? ""].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $record.kind) {
                    ForEach(["Hotel", "Flight", "Transport"], id: \.self) { Text($0).tag($0) }
                }
                TextField(record.kind == "Hotel" ? "Hotel name (optional)" : "Airline / operator (optional)", text: $record.name)
                TextField(record.kind == "Flight" ? "Flight number (optional)" : "Booking reference (optional)", text: $record.reference)
                TextField(record.kind == "Hotel" ? "Hotel address (optional)" : "From (optional)", text: $record.from)
                if record.kind != "Hotel" { TextField("To (optional)", text: $record.to) }
            }
            bookingSection
            Section("Dates") {
                DatePicker(record.kind == "Hotel" ? "Check-in" : "Departure", selection: $record.start)
                    .environment(\.timeZone, record.zone(start: true))
                timeZoneButton(start: true)
                DatePicker(record.kind == "Hotel" ? "Check-out" : "Arrival / return", selection: $record.end)
                    .environment(\.timeZone, record.zone(start: false))
                timeZoneButton(start: false)
                Text("Choose each location to enter its local time. Changing a time zone preserves the scheduled instant; review the displayed dates and times.").font(.subheadline).foregroundStyle(.secondary)
                if let warning = record.dateWarning { Label(warning, systemImage: "exclamationmark.triangle").foregroundStyle(.orange).font(.subheadline) }
            }
            Section("Notes") {
                TextEditor(text: $record.note).frame(minHeight: 180).accessibilityLabel("Travel notes")
                if !draftStatus.isEmpty { Text(draftStatus).font(.subheadline).foregroundStyle(.secondary) }
            }
            Section("Reminder") {
                Picker(record.kind == "Hotel" ? "Before check-in" : "Before departure", selection: Binding(get: { record.reminderMinutes ?? 0 }, set: { record.reminderMinutes = $0 == 0 ? nil : $0 })) {
                    Text("Off").tag(0)
                    Text("15 minutes").tag(15); Text("30 minutes").tag(30); Text("1 hour").tag(60); Text("2 hours").tag(120); Text("1 day").tag(1440)
                }
                Text("Scheduled for the booking’s actual time, even if your phone changes time zones. Notification text keeps booking details private.").font(.subheadline).foregroundStyle(.secondary)
                if let fire = TripReminderStore.fireDate(for: record), fire <= Date() { Text("This reminder time has passed. Choose a shorter lead time or update the departure/check-in date.").font(.subheadline).foregroundStyle(.orange) }
                TripReminderStatus(store: trip.reminders)
            }
            if trip.records.contains(where: { $0.id == record.id }) {
                TripRecordDocuments(recordID: record.id)
                Section { Button("Delete travel entry", role: .destructive) { deleting = true } }
            } else {
                Section("Documents") { Text("Save these travel details, then add PDFs or images.").font(.subheadline).foregroundStyle(.secondary) }
            }
            Section {
                if let error = trip.error {
                    Text(error).font(.subheadline).foregroundStyle(.red)
                    Button("Retry save") { save() }.disabled(saving || !trip.unlocked || !hasDetails || record.dateWarning != nil)
                }
            }
        }
        .disabled(saving)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                TripActionButton(saving ? "Saving…" : "Save", primary: true) { save() }.disabled(!hasDetails || saving || !trip.unlocked || record.dateWarning != nil)
            }.tripToolbarBackground()
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: record) { _, value in
            draftTask?.cancel()
            draftStatus = "Saving draft…"
            draftTask = Task { @MainActor in
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard !Task.isCancelled, !saving else { return }
                draftStatus = trip.saveDraft(value) ? "Draft saved on this iPhone" : "Draft could not be saved. Keep this editor open and retry."
            }
        }
        .onChange(of: phase) { _, value in if value == .inactive && hasDetails { draftTask?.cancel(); _ = trip.saveDraft(record) } }
        .onDisappear { draftTask?.cancel(); if hasDetails && !saving && !completed { _ = trip.saveDraft(record) } }
        .sheet(isPresented: Binding(get: { choosingStart != nil }, set: { if !$0 { choosingStart = nil } })) {
            TripCityPicker { city in
                if choosingStart == true { record.departureTimeZone = city.timeZoneID; record.departureCity = city.name }
                else { record.arrivalTimeZone = city.timeZoneID; record.arrivalCity = city.name }
                choosingStart = nil
                return nil
            }
        }
        .confirmationDialog("Delete this travel entry?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete travel entry", role: .destructive) { do { try trip.removeRecord(record.id); completed = true; draftTask?.cancel(); onSave?() } catch { trip.error = error.localizedDescription } }
        } message: { Text("Attached documents stay in Documents. You can reassign or delete them there.") }
        .onChange(of: trip.unlocked) { _, unlocked in if !unlocked { onSave?() } }
    }
    private var bookingSection: some View {
            Section("Booking & traveler") {
                TextField("Traveler (optional)", text: Binding(get: { record.traveler ?? "" }, set: { record.traveler = $0 })).textContentType(.name)
                if record.kind == "Flight" {
                    TextField("Booking reference (optional)", text: Binding(get: { record.bookingReference ?? "" }, set: { record.bookingReference = $0 })).textInputAutocapitalization(.characters).autocorrectionDisabled()
                }
                let reference = record.kind == "Flight" ? (record.bookingReference ?? "") : record.reference
                if !reference.isEmpty {
                    Button { UIPasteboard.general.string = reference; copied = true } label: { Label(copied ? "Reference copied" : "Copy booking reference", systemImage: copied ? "checkmark" : "doc.on.doc") }
                }
                TextField("Booking website (https://…)", text: Binding(get: { record.bookingWebsite ?? "" }, set: { record.bookingWebsite = $0 })).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                if record.kind == "Flight" {
                    Menu("Choose airline website") {
                        ForEach(TripBookingLink.airlines) { airline in Button(airline.name) { record.bookingWebsite = airline.url } }
                    }
                }
                if let url = TripBookingLink.url(record.bookingWebsite) { Link(destination: url) { Label("Open booking website", systemImage: "arrow.up.right.square") } }
                Text("Opens in your browser. Copy your reference above and enter it on the provider’s site. Tama World Clock does not sign in or sync bookings.").font(.subheadline).foregroundStyle(.secondary)
            }
    }
    private func save() {
        guard !saving, trip.unlocked else { return }
        draftTask?.cancel()
        guard record.dateWarning == nil else { trip.error = record.dateWarning; return }
        if let website = record.bookingWebsite, !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, TripBookingLink.url(website) == nil { trip.error = "Enter a valid https:// booking website."; return }
        trip.error = nil
        saving = true
        let value = record
        Task {
            defer { saving = false }
            if value.reminderMinutes != nil { _ = await trip.reminders.requestAccess() }
            if trip.save(value) { completed = true; onSave?() }
        }
    }
    private func timeZoneButton(start: Bool) -> some View {
        let name = start ? record.departureCity : record.arrivalCity
        return Button { choosingStart = start } label: {
            HStack {
                Text(record.kind == "Hotel" ? (start ? "Check-in time zone" : "Check-out time zone") : (start ? "Departure time zone" : "Arrival time zone")).foregroundStyle(.secondary)
                Spacer()
                Text(name ?? (record.kind == "Hotel" && !start ? record.departureCity : nil) ?? "Device time")
                Image(systemName: "magnifyingglass")
            }.font(.subheadline).frame(minHeight: 44)
        }.buttonStyle(.plain)
    }

}

struct TripReminderStatus: View {
    @ObservedObject var store: TripReminderStore
    var body: some View { if let message = store.message { Text(message).font(.subheadline).foregroundStyle(.orange) } }
}

