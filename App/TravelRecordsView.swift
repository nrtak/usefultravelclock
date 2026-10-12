import SwiftUI
import UIKit

struct TravelRecordsView: View {
    @EnvironmentObject private var trip: TripStore
    @EnvironmentObject private var inbox: TripDocumentInbox
    @Environment(\.scenePhase) private var phase
    @State private var draft: TravelRecord?
    @State private var preview: TripPreviewFile?
    @State private var incoming: TripPreviewFile?
    private var nextDocument: TripDocument? {
        let now = Date()
        let record = entries.first { $0.start >= now } ?? entries.first { $0.end >= now }
        return trip.documents.filter { $0.recordID == record?.id && record != nil }.sorted { ($0.kind == .boardingPass ? 0 : 1) < ($1.kind == .boardingPass ? 0 : 1) }.first
    }
    private var entries: [TravelRecord] { trip.records.sorted { $0.start < $1.start } }
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
            } else if entries.isEmpty {
                RecordForm(record: TravelRecord())
            } else {
                List {
                    if let document = nextDocument {
                        Section("Next trip document") {
                            Button {
                                do { preview = TripPreviewFile(url: try trip.previewURL(document)) } catch { trip.error = error.localizedDescription }
                            } label: { TripDocumentRow(document: document, record: trip.records.first { $0.id == document.recordID }, available: trip.documentAvailable(document)) }
                        }
                    }
                    Section {
                        Button { draft = TravelRecord() } label: {
                            Label("Add", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(entries) { record in
                        Button { draft = record } label: {
                            HStack(spacing: 14) {
                                Image(systemName: record.kind == "Hotel" ? "bed.double" : record.kind == "Flight" ? "airplane" : "tram")
                                    .font(.title2).foregroundStyle(.orange).frame(width: 32)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.name.isEmpty ? record.kind : record.name).font(.headline)
                                    Text((record.kind == "Hotel" ? "Check-in · " : "Departure · ") + record.timeLabel(start: true)).font(.subheadline)
                                    Text((record.kind == "Hotel" ? "Check-out · " : "Arrival · ") + record.timeLabel(start: false)).font(.caption).foregroundStyle(.secondary)
                                    if !record.reference.isEmpty { Text(record.reference).font(.caption) }
                                    if !record.from.isEmpty { Text(record.from + (record.to.isEmpty ? "" : " → " + record.to)).font(.caption).lineLimit(2) }
                                }
                            }.foregroundStyle(Color.primary).padding(.vertical, 4)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { NavigationLink { TripDocumentsView() } label: { Image(systemName: "doc.on.doc").frame(width: 44, height: 44) }.accessibilityLabel("Documents") } }
        .sheet(item: $draft) { record in RecordEditor(record: record) }
        .sheet(item: $preview, onDismiss: { trip.clearDocumentPreviews() }) { file in TripOriginalPreview(url: file.url).ignoresSafeArea() }
        .sheet(item: $incoming, onDismiss: { inbox.clear() }) { file in TripDocumentImport(recordID: nil, incomingURL: file.url) }
        .onAppear { receiveDocument() }
        .onChange(of: inbox.url) { _, _ in receiveDocument() }
        .onChange(of: trip.unlocked) { _, value in if value { receiveDocument() } else { preview = nil; incoming = nil } }
        .onChange(of: phase) { _, value in if value == .background { preview = nil; trip.clearDocumentPreviews() } }
    }
    private func receiveDocument() {
        guard trip.unlocked, let url = inbox.url, incoming == nil else { return }
        draft = nil
        incoming = TripPreviewFile(url: url)
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
                        ForEach(TripBookingLink.airlines, id: \.name) { airline in Button(airline.name) { record.bookingWebsite = airline.url } }
                    }
                }
                if let url = TripBookingLink.url(record.bookingWebsite) { Link(destination: url) { Label("Open booking website", systemImage: "arrow.up.right.square") } }
                Text("Opens in your browser. Copy your reference above and enter it on the provider’s site. Trip Info does not sign in or sync bookings.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Dates") {
                DatePicker(record.kind == "Hotel" ? "Check-in" : "Departure", selection: $record.start)
                    .environment(\.timeZone, record.zone(start: true))
                timeZoneButton(start: true)
                DatePicker(record.kind == "Hotel" ? "Check-out" : "Arrival / return", selection: $record.end, in: record.start...)
                    .environment(\.timeZone, record.zone(start: false))
                timeZoneButton(start: false)
                Text("Choose each location to enter its local time. Changing a time zone preserves the scheduled instant; review the displayed dates and times.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                TextField("Notes (optional)", text: $record.note, axis: .vertical).lineLimit(2...4)
            }
            if trip.records.contains(where: { $0.id == record.id }) {
                TripRecordDocuments(recordID: record.id)
                Section { Button("Delete travel entry", role: .destructive) { deleting = true } }
            } else {
                Section("Documents") { Text("Save these travel details, then add PDFs or images.").font(.caption).foregroundStyle(.secondary) }
            }
            Section {
                if let error = trip.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                TripActionButton("Save", primary: true) { save() }.disabled(!hasDetails)
            }.tripToolbarBackground()
        }
        .onChange(of: record.start) { _, start in if record.end < start { record.end = start } }
        .sheet(isPresented: Binding(get: { choosingStart != nil }, set: { if !$0 { choosingStart = nil } })) {
            TripCityPicker { city in
                if choosingStart == true { record.departureTimeZone = city.timeZoneID; record.departureCity = city.name }
                else { record.arrivalTimeZone = city.timeZoneID; record.arrivalCity = city.name }
                choosingStart = nil
            }
        }
        .confirmationDialog("Delete this travel entry?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete travel entry", role: .destructive) { do { try trip.removeRecord(record.id); onSave?() } catch { trip.error = error.localizedDescription } }
        } message: { Text("Attached documents stay in Documents. You can reassign or delete them there.") }
        .onChange(of: trip.unlocked) { _, unlocked in if !unlocked { onSave?() } }
    }
    private func save() {
        if record.end < record.start { record.end = record.start }
        if let website = record.bookingWebsite, !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, TripBookingLink.url(website) == nil { trip.error = "Enter a valid https:// booking website."; return }
        trip.error = nil
        trip.save(record)
        if trip.error == nil { onSave?() }
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

