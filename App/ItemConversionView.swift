import SwiftUI

struct ItemPrice: Identifiable {
    let id = UUID()
    var text = ""
}

struct ItemConversionView: View {
    @ObservedObject var store: ConverterStore
    @Environment(\.dismiss) private var dismiss
    @State private var items = [ItemPrice()]
    @State private var page = 0
    @State private var selectedID: UUID?
    @State private var picker: CurrencySide?
    private let pageSize = 3
    private enum CurrencySide: String, Identifiable {
        case source, target
        var id: String { rawValue }
    }
    private var total: Decimal? { ItemAmounts.total(items.map(\.text)) }
    private var pages: Int { max(1, (items.count + pageSize - 1) / pageSize) }
    private var converted: Decimal? {
        guard let total else { return nil }
        if store.source == store.target { return total }
        guard let multiplier = store.snapshot?.multiplier(from: store.source, to: store.target) else { return nil }
        return total * multiplier
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .padding(.horizontal, 16)
        .navigationTitle("Add multiple prices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } } }
        .sheet(item: $picker) { side in
            CurrencyPicker(store: store, title: "Search currency") { code in
                if side == .source { store.source = code } else { store.target = code }
                picker = nil
            }
        }
        .onAppear { selectedID = items.first?.id }
    }

    private var content: some View {
        VStack(spacing: 10) {
            CurrencyPairControl(store: store)
            TripRateStatus(store: store).font(.caption2).foregroundStyle(.secondary)
            ForEach(Array(items.enumerated()).filter { $0.offset / pageSize == page }, id: \.element.id) { pair in
                HStack {
                    Text("Item \(pair.offset + 1)").font(.subheadline)
                    Button { selectedID = pair.element.id } label: {
                        Text(pair.element.text.isEmpty ? "0" : pair.element.text)
                            .monospacedDigit().frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing).padding(.horizontal, 10)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedID == pair.element.id ? Color.blue : .clear))
                    }.buttonStyle(.plain).accessibilityLabel("Edit item \(pair.offset + 1), \(pair.element.text)")
                    Button { remove(pair.element.id) } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .accessibilityLabel("Remove item \(pair.offset + 1)")
                }
            }
            HStack {
                Button { page -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(page == 0).accessibilityLabel("Previous items")
                Text("\(page + 1) / \(pages)").font(.caption)
                Button { page += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(page + 1 == pages).accessibilityLabel("Next items")
                Spacer()
                Button("Add item", systemImage: "plus") {
                    let item = ItemPrice()
                    items.append(item); selectedID = item.id; page = (items.count - 1) / pageSize
                }.frame(minHeight: 44)
            }
            HStack {
                totalColumn("Total · \(store.source)", value: total, code: store.source)
                totalColumn("Converted · \(store.target)", value: converted, code: store.target)
            }.padding(12).background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            Text(total == nil ? "Check the selected amount." : rateMessage).font(.caption2).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(["1","2","3","4","5","6","7","8","9",Locale.current.decimalSeparator ?? ".","0","⌫"], id: \.self) { key in
                    Button { enter(key) } label: { Text(key).font(.title3).frame(maxWidth: .infinity, minHeight: 44) }
                        .buttonStyle(.bordered).accessibilityLabel(key == "⌫" ? "Delete digit" : key)
                }
            }
            Button("Use total") {
                guard let total else { return }
                store.edit(ItemAmounts.editable(total), side: .source)
                dismiss()
            }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity, minHeight: 44).disabled(total == nil || converted == nil)
        }.padding(.vertical, 8)
    }

    private var rateMessage: String {
        if store.source == store.target { return "Same currency · No conversion needed" }
        guard converted != nil else { return "Rate unavailable. Refresh rates from the currency screen." }
        let dates = store.snapshot?.dates(from: store.source, to: store.target) ?? []
        return "Rates as of " + dates.joined(separator: " / ")
    }
    private func totalColumn(_ label: String, value: Decimal?, code: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption)
            Text(value.map { Currency.named(code).symbol + " " + Amount.format($0, currency: .named(code)) } ?? "—")
                .font(.title2.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func enter(_ key: String) {
        guard let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        if key == "⌫" { if !items[index].text.isEmpty { items[index].text.removeLast() }; return }
        let separator = Locale.current.decimalSeparator ?? "."
        if key == separator && items[index].text.contains(separator) { return }
        guard items[index].text.count < 18 else { return }
        if key == separator && items[index].text.isEmpty { items[index].text = "0" }
        items[index].text += key
    }
    private func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        if items.isEmpty { items = [ItemPrice()] }
        page = min(page, pages - 1)
        if selectedID == id { selectedID = items[min(page * pageSize, items.count - 1)].id }
    }
}
