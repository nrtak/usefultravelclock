import SwiftUI

struct TravelRecordsView: View {
    @EnvironmentObject private var trip: TripStore
    @State private var draft: TravelRecord?
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
                .toolbar { ToolbarItem(placement: .cancellationAction) { TripNavigationButton(title: "Back") { dismiss() } }.tripToolbarBackground() }
        }
    }
}

struct RecordForm: View {
    @EnvironmentObject private var trip: TripStore
    @State var record: TravelRecord
    var onSave: (() -> Void)? = nil
    @State private var choosingStart: Bool?
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
        .onChange(of: trip.unlocked) { _, unlocked in if !unlocked { onSave?() } }
    }
    private func save() {
        if record.end < record.start { record.end = record.start }
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
