import SwiftUI

struct SavedTranslationsView: View {
    @EnvironmentObject private var trip: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var deleting: TranslationRecord?
    var body: some View {
        NavigationStack {
            List {
                if trip.canUndoTranslationDeletion {
                    Section { Button("Undo last translation deletion", systemImage: "arrow.uturn.backward") { _ = trip.undoTranslationDeletion() } }
                }
                let matches = trip.translations.filter { $0.matches(query) }
                if matches.isEmpty {
                    ContentUnavailableView(trip.translations.isEmpty ? "Keep useful phrases" : "No matching translations", systemImage: "character.bubble", description: Text(trip.translations.isEmpty ? "Translate text or a photo, then tap Save to keep it on this iPhone." : "Search a title, translation or note."))
                }
                ForEach(matches) { record in
                    NavigationLink { SavedTranslationEditor(record: record) } label: {
                        HStack {
                            if let data = record.image { TripPhotoThumbnail(id: "translation-" + record.id.uuidString, data: data).accessibilityHidden(true) }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(record.displayTitle).font(.headline).lineLimit(2)
                                if !record.note.isEmpty { Text(record.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                            }
                        }.accessibilityElement(children: .combine)
                    }.swipeActions { Button("Delete", role: .destructive) { deleting = record } }
                    .accessibilityAction(named: "Delete translation") { deleting = record }
                }
            }.searchable(text: $query, prompt: "Title, translation or note")
                .navigationTitle("Saved translations")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Delete this saved translation?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("Delete translation", role: .destructive) { if let deleting { _ = trip.deleteTranslation(deleting.id) }; deleting = nil }
                } message: { Text("Undo restores the most recent deletion while the app remains open.") }
                .alert("Couldn’t save changes", isPresented: Binding(get: { trip.error != nil }, set: { if !$0 { trip.error = nil } })) { Button("OK") { trip.error = nil } } message: { Text(trip.error ?? "") }
        }
    }
}
