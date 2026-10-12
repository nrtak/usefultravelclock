import SwiftUI

struct PriceCorrectionView: View {
    let currency: Currency
    let save: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String
    @State private var error = false
    @FocusState private var focused: Bool
    init(price: RecognizedPrice, currency: Currency, save: @escaping (String) -> Bool) {
        self.currency = currency; self.save = save
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 8
        _amount = State(initialValue: formatter.string(from: NSDecimalNumber(decimal: price.value)) ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Recognized price · " + currency.code) {
                    HStack {
                        Text(currency.symbol).font(.title2)
                        TextField("Amount", text: $amount).font(.title2).keyboardType(.decimalPad).focused($focused)
                            .accessibilityLabel("Correct price in " + currency.name)
                    }
                    Text("Enter the amount shown on the original menu or tag. Its conversion updates after saving.").font(.caption).foregroundStyle(.secondary)
                    if error { Text("Enter a positive amount or zero using your decimal separator.").foregroundStyle(.red).font(.caption) }
                }
            }.navigationTitle("Correct price").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } }.tripToolbarBackground()
                ToolbarItem(placement: .confirmationAction) { TripActionButton("Save", primary: true) { if save(amount) { dismiss() } else { error = true } } }.tripToolbarBackground()
            }.onAppear { focused = true }
        }
    }
}
