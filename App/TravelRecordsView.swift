import SwiftUI

struct TravelRecordsView: View {
    @EnvironmentObject private var trip: TripStore
    @State private var draft: TravelRecord?
    private var entries: [TravelRecord] { trip.records.sorted { $0.start < $1.start } }
    var body: some View {
        Group {
            if !trip.unlocked {
                VStack(spacing: 16) {
                    ContentUnavailableView("Travel details locked", systemImage: "lock", description: Text("Unlock your lodging and transportation."))
                    Button("Unlock") { Task { await trip.unlock() } }.buttonStyle(.borderedProminent)
                }
            } else if entries.isEmpty {
                RecordForm(record: TravelRecord())
            } else {
                List {
                    Section {
                        Button { draft = TravelRecord() } label: {
                            Label("Add", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(entries) { record in
                        Button { draft = record } label: {
                            HStack(spacing: 14) {
                                Image(systemName: record.kind == "Hotel" ? "bed.double" : record.kind == "Flight" ? "airplane" : "tram")
                                    .font(.title2).frame(width: 32)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(record.name.isEmpty ? record.kind : record.name).font(.headline)
                                    Text(record.start.formatted(date: .abbreviated, time: .shortened)).font(.subheadline)
                                    if !record.reference.isEmpty { Text(record.reference).font(.caption) }
                                    if !record.from.isEmpty { Text(record.from + (record.to.isEmpty ? "" : " → " + record.to)).font(.caption).lineLimit(2) }
                                }
                            }.foregroundStyle(.primary).padding(.vertical, 4)
                        }
                    }
                }
            }
        }.navigationBarTitleDisplayMode(.inline)
        .sheet(item: $draft) { record in RecordEditor(record: record) }
    }
}

struct RecordEditor: View {
    @Environment(\.dismiss) private var dismiss
    var record: TravelRecord
    var body: some View {
        NavigationStack {
            RecordForm(record: record, onSave: { dismiss() })
                .navigationTitle("Travel details").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { TripNavigationButton(title: "Back") { dismiss() } } }
        }
    }
}

struct RecordForm: View {
    @EnvironmentObject private var trip: TripStore
    @State var record: TravelRecord
    var onSave: (() -> Void)? = nil
    private var hasDetails: Bool {
        [record.name, record.reference, record.from, record.to, record.note].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
            Section("Dates") {
                DatePicker(record.kind == "Hotel" ? "Check-in" : "Departure", selection: $record.start)
                DatePicker(record.kind == "Hotel" ? "Check-out" : "Arrival / return", selection: $record.end, in: record.start...)
                Text("Times use your device’s time zone.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                TextField("Notes (optional)", text: $record.note, axis: .vertical).lineLimit(2...4)
            }
            Section {
                if let error = trip.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                TripActionButton("Save", primary: true) { save() }.disabled(!hasDetails)
            }
        }
        .onChange(of: record.start) { _, start in if record.end < start { record.end = start } }
        .onChange(of: trip.unlocked) { _, unlocked in if !unlocked { onSave?() } }
    }
    private func save() {
        if record.end < record.start { record.end = record.start }
        trip.error = nil
        trip.save(record)
        if trip.error == nil { onSave?() }
    }

}
