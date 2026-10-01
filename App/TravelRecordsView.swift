import SwiftUI

struct TravelRecordsView: View {
    @EnvironmentObject private var trip: TripStore
    @State private var kind = "Hotel"
    @State private var draft: TravelRecord?
    @State private var page = 0
    private var entries: [TravelRecord] { trip.records.filter { $0.kind == kind }.sorted { $0.start < $1.start } }
    var body: some View {
        VStack(spacing: 16) {
            Picker("Category", selection: $kind) { ForEach(["Hotel", "Flight", "Transport"], id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented)
            if !trip.unlocked {
                ContentUnavailableView("Travel details locked", systemImage: "lock", description: Text("Unlock to view or add lodging and transportation."))
                Button("Unlock") { Task { await trip.unlock() } }.buttonStyle(.borderedProminent)
            } else {
                HStack { Text(kind == "Hotel" ? "Hotel stays" : kind + " details").font(.headline); Spacer(); Button("＋ Add") { draft = TravelRecord(kind: kind) } }
                if entries.isEmpty { ContentUnavailableView("No records yet", systemImage: kind == "Hotel" ? "bed.double" : "suitcase") }
                ForEach(Array(entries.dropFirst(page * 3).prefix(3))) { record in
                    Button { draft = record } label: { HStack { VStack(alignment: .leading, spacing: 6) { Text(record.name).font(.headline); Text(record.start.formatted(date: .abbreviated, time: .shortened)).font(.caption); Text(record.reference).font(.caption) }; Spacer(); Image(systemName: "chevron.right") }.padding().frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.bordered)
                }
                if entries.count > 3 { HStack { Button("Previous") { page -= 1 }.disabled(page == 0); Spacer(); Text("\(page+1) / \((entries.count+2)/3)"); Spacer(); Button("Next") { page += 1 }.disabled((page+1)*3 >= entries.count) } }
            }
            Spacer()
        }.padding().navigationBarTitleDisplayMode(.inline).onChange(of: kind) { _, _ in page = 0 }
        .sheet(item: $draft) { record in RecordEditor(record: record) }
    }
}
struct RecordEditor: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State var record: TravelRecord
    @State private var step = 0
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if step == 0 {
                    Text(record.kind == "Hotel" ? "Hotel name" : "Airline / operator").font(.caption)
                    TextField("Name", text: $record.name).textFieldStyle(.roundedBorder)
                    TextField(record.kind == "Flight" ? "Flight number" : "Booking reference", text: $record.reference).textFieldStyle(.roundedBorder)
                    TextField(record.kind == "Hotel" ? "Hotel address" : "From", text: $record.from).textFieldStyle(.roundedBorder)
                    if record.kind != "Hotel" { TextField("To", text: $record.to).textFieldStyle(.roundedBorder) }
                    Button("Dates & notes →") { step = 1 }.buttonStyle(.borderedProminent).disabled(record.name.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    DatePicker(record.kind == "Hotel" ? "Check-in" : "Departure", selection: $record.start)
                    DatePicker(record.kind == "Hotel" ? "Check-out" : "Arrival / return", selection: $record.end, in: record.start...)
                    Text("Dates use this device’s time zone. Flight-specific time zones will be added before release.").font(.caption).foregroundStyle(.secondary)
                    Text("Notes").font(.caption)
                    TextEditor(text: $record.note).frame(height: 130).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    Button("Save details") { if record.end < record.start { record.end = record.start }; trip.save(record); if trip.error == nil { dismiss() } }.buttonStyle(.borderedProminent)
                }
                Spacer()
            }.padding().navigationTitle(record.kind + " details").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(step == 0 ? "Cancel" : "Back") { if step == 0 { dismiss() } else { step = 0 } } } }
                .onChange(of: trip.unlocked) { _, value in if !value { dismiss() } }
        }
    }
}
