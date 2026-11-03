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

    static func moving(_ item: Self, to target: Self, in saved: String) -> String {
        var items = decode(saved)
        guard let from = items.firstIndex(of: item), let to = items.firstIndex(of: target), from != to else { return saved }
        items.remove(at: from); items.insert(item, at: to)
        return encode(items)
    }

    static func selecting(_ item: Self, in saved: String, capacity: Int, replacing old: Self? = nil) -> String {
        guard capacity > 0 else { return saved }
        var items = decode(saved)
        let visible = Array(items.prefix(capacity))
        guard !visible.contains(item) else { return saved }
        if let old {
            guard visible.contains(old) else { return saved }
            items.removeAll { $0 == item }
            guard let index = items.firstIndex(of: old) else { return saved }
            items[index] = item
        } else {
            guard visible.count < capacity else { return saved }
            items.removeAll { $0 == item }
            items.insert(item, at: visible.count)
        }
        return encode(items)
    }
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
    @State private var replacement: HomeSection?
    @State private var editMode = EditMode.inactive
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    private var rowBackground: Color { Color(.secondarySystemGroupedBackground).opacity(reduceTransparency ? 1 : 0.65) }
    private var sections: [HomeSection] { HomeSection.decode(savedSections) }
    private var visible: [HomeSection] { Array(sections.prefix(capacity)) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Add, replace or reorder Home cards. Changes appear on Home as you make them.")
                    Text("Up to \(capacity) cards fit with your current screen and text size. Home stays on one screen; cards that do not fit remain saved here." + (typeSize.isAccessibilitySize ? "" : " Drag this sheet up for more room.")).font(.subheadline).foregroundStyle(.secondary)
                }.listRowBackground(rowBackground)
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
                }.listRowBackground(rowBackground)
                Section("Available cards") {
                    ForEach(HomeSection.allCases.filter { !visible.contains($0) }) { item in
                        Button {
                            if visible.count >= capacity { replacement = item }
                            else { savedSections = HomeSection.selecting(item, in: savedSections, capacity: capacity) }
                        } label: { Label(item.title, systemImage: "plus.circle") }
                            .disabled(capacity == 0)
                            .accessibilityHint(visible.count >= capacity ? "Choose a Home card to replace" : "Add to Home")
                    }
                    if capacity == 0 {
                        Text("No cards fit at the current screen and text size. Your choices stay saved.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }.listRowBackground(rowBackground)
                Section {
                    Button("Restore default cards") { savedSections = HomeSection.defaults }
                }.listRowBackground(rowBackground)
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $editMode)
            .navigationTitle("Customize Home").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editMode == .active ? "Finish reordering" : "Reorder") {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Replace a Home card", isPresented: Binding(get: { replacement != nil }, set: { if !$0 { replacement = nil } }), titleVisibility: .visible) {
                if let replacement {
                    ForEach(visible) { old in
                        Button("Replace \(old.title)") {
                            savedSections = HomeSection.selecting(replacement, in: savedSections, capacity: capacity, replacing: old)
                            self.replacement = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { replacement = nil }
            } message: {
                if let replacement { Text("Choose where to show \(replacement.title). Home stays on one screen.") }
            }
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .modifier(HomeCustomizationSurface(reduceTransparency: reduceTransparency))
    }
}

private struct HomeCustomizationSurface: ViewModifier {
    let reduceTransparency: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.presentationBackground(Color(.systemBackground))
        } else if #available(iOS 26.0, *) {
            // Native partial-height sheets provide Liquid Glass on iOS 26.
            content
        } else {
            content.presentationBackground(.thinMaterial)
        }
    }
}
