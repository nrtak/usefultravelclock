import SwiftUI

/// Shared searchable currency selection for photo prices and item totals.
struct CurrencyPairControl: View {
    @ObservedObject var store: ConverterStore
    @State private var selection: Side?
    private enum Side: String, Identifiable {
        case source, target
        var id: String { rawValue }
    }
    var body: some View {
        HStack(spacing: 8) {
            currencyButton("From", code: store.source, side: .source)
            Button {
                let source = store.source
                store.source = store.target
                store.target = source
            } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 44, height: 44) }
                .accessibilityLabel("Swap currencies")
            currencyButton("To", code: store.target, side: .target)
        }
        .sheet(item: $selection) { side in
            CurrencyPicker(store: store, title: side == .source ? "Convert from" : "Convert to") { code in
                if side == .source { store.source = code } else { store.target = code }
                selection = nil
            }
        }
    }
    private func currencyButton(_ label: String, code: String, side: Side) -> some View {
        let currency = Currency.named(code)
        return Button { selection = side } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack { Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Image(systemName: "magnifyingglass").font(.caption) }
                Text("\(currency.symbol) \(code)").font(.headline)
                Text(currency.countryLabel).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel("\(label): \(currency.name), \(currency.countryLabel). Change currency")
    }
}
