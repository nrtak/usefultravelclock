import SwiftUI

enum HomeSection: String, CaseIterable, Identifiable {
    case clocks, currency, trip, weather, documents, readiness
    var id: String { rawValue }
    static let defaults = "clocks,currency,trip"
    var title: String {
        switch self {
        case .clocks: return "Home & destination time"
        case .currency: return "Currency"
        case .trip: return "Next booking"
        case .weather: return "Weather"
        case .documents: return "Saved document"
        case .readiness: return "Before you leave"
        }
    }
    var symbol: String {
        switch self {
        case .clocks: return "clock"
        case .currency: return "banknote"
        case .trip: return "suitcase"
        case .weather: return "cloud.sun"
        case .documents: return "doc.text"
        case .readiness: return "checklist"
        }
    }
    static func decode(_ value: String) -> [Self] {
        var seen = Set<Self>()
        let items = value.split(separator: ",").compactMap { Self(rawValue: String($0)) }
            .filter { seen.insert($0).inserted }
        // An empty Home is a deliberate choice. Recover corrupt nonempty settings.
        return items.isEmpty && !value.isEmpty ? decode(defaults) : items
    }
    static func encode(_ items: [Self]) -> String { items.map(\.rawValue).joined(separator: ",") }
}

enum HomeLayout {
    static let spacing: CGFloat = 10
    static let padding: CGFloat = 12
    static func capacity(height: CGFloat, cardHeight: CGFloat) -> Int {
        guard height.isFinite, cardHeight.isFinite, cardHeight > 0 else { return 0 }
        let space = max(0, height - 2 * padding)
        let count = min(CGFloat(HomeSection.allCases.count), (space + spacing) / (cardHeight + spacing))
        return max(0, Int(count))
    }
}

struct HomeCustomizationView: View {
    @Binding var savedSections: String
    let capacity: Int
    @Environment(\.dismiss) private var dismiss
    private var sections: [HomeSection] { HomeSection.decode(savedSections) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose what appears on Home. Up to \(capacity) cards fit with your current screen and text size. Drag to change their order.")
                    Text("Home never scrolls. If less space becomes available, the first cards stay visible and the rest remain saved here. Every feature is also available in My Trip or Tools.").font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Your cards · \(min(capacity, sections.count)) shown") {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, item in
                        Label(item.title, systemImage: item.symbol)
                            .accessibilityValue(index < capacity ? "Shown on Home" : "Saved, currently does not fit")
                            .foregroundStyle(index < capacity ? Color.primary : Color.secondary)
                    }
                    .onMove { from, to in
                        var items = sections; items.move(fromOffsets: from, toOffset: to)
                        savedSections = HomeSection.encode(items)
                    }
                    .onDelete { offsets in
                        var items = sections; items.remove(atOffsets: offsets)
                        savedSections = HomeSection.encode(items)
                    }
                }
                Section("Available cards") {
                    ForEach(HomeSection.allCases.filter { !sections.contains($0) }) { item in
                        Button {
                            guard sections.count < capacity else { return }
                            savedSections = HomeSection.encode(sections + [item])
                        } label: { Label(item.title, systemImage: "plus.circle") }
                            .disabled(sections.count >= capacity)
                    }
                    if sections.count >= capacity {
                        Text("Remove a card to make room for another.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Restore default cards") { savedSections = HomeSection.defaults }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize Home").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
