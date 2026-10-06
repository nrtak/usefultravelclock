import SwiftUI
import UIKit

private enum PickerSide: String, Identifiable { case source, target; var id: String { rawValue } }

struct CurrencyConverterView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var featureIconSize = 36.0
    @ObservedObject var store: ConverterStore
    var onBack: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var picker: PickerSide?
    @StateObject private var saved = SavedConversions()
    @State private var draft: SavedConversion?
    @State private var showsSaved = false
    @State private var showsItems = false
    @State private var showsPhotoPrices = false
    @State private var showsUnits = false
    @State private var copiedAmount = false
    @AppStorage("trip-currency-color") private var boxColor = "F3F3F3"
    @FocusState private var editingSide: AmountSide?
    private var editing: Bool { editingSide != nil }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 8) {
                        VStack(spacing: 6) {
                            HStack {
                                TripSectionLabel(title: "Currency", symbol: "banknote")
                                Spacer()
                                Button { editingSide = nil; store.swap() } label: {
                                    Image(systemName: "arrow.up.arrow.down").font(.title3).frame(width: 44, height: 44)
                                }.buttonStyle(.plain).accessibilityLabel("Swap currencies")
                            }
                            amountCard(source: true)
                            amountCard(source: false)
                            rateDetails
                        }.tripPanel().id("amounts")

                        if !editing {
                            HStack(spacing: 10) {
                                featureTile("Add multiple prices", detail: "Convert their total.", icon: "list.bullet.rectangle") { showsItems = true }
                                featureTile("Live camera / photo", detail: "Read and convert prices.", icon: "camera.viewfinder") { showsPhotoPrices = true }
                            }.frame(height: geometry.size.height < 600 ? 64 : 80)
                            saveButtons
                            SavedConversionNotice(saved: saved) { showsSaved = true }
                            Button { showsUnits = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "ruler").foregroundStyle(.teal)
                                    Text("Unit converter").font(.subheadline.weight(.medium)).foregroundStyle(Color.primary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityHint("Convert distance, temperature, volume and weight")
                            VStack(spacing: 0) {
                                Text("Rates: Frankfurter · Bank rates may differ.")
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            }
                        }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .navigationTitle("Conversions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onBack {
                    ToolbarItem(placement: .topBarTrailing) {
                        TripNavigationButton(title: "Back") { editingSide = nil; onBack() }
                    }.tripToolbarBackground()
                }
                if editing {
                    ToolbarItem(placement: .topBarLeading) {
                        TripNavigationButton(title: "Done") { editingSide = nil }
                    }.tripToolbarBackground()
                }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editingSide = nil } }
            }
            .sheet(item: $picker) { side in CurrencyPicker(store: store, title: side == .target ? "Search currency" : "Convert from", select: { code in
                if side == .source { store.source = code } else { store.target = code }; picker = nil
            }) }
            .sheet(isPresented: $showsItems) { NavigationStack { ItemConversionView(store: store) } }
            .sheet(isPresented: $showsPhotoPrices) { NavigationStack { PriceImageView(store: store, savedPrices: saved).toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Done") { showsPhotoPrices = false }  }.tripToolbarBackground() } } }
            .sheet(item: $draft) { entry in SaveConversionView(draft: entry, saved: saved) }
            .sheet(isPresented: $showsSaved) { SavedConversionsView(saved: saved) }
            .sheet(isPresented: $showsUnits) {
                NavigationStack {
                    TripUnitsView().toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            TripNavigationButton(title: "Back") { showsUnits = false }
                        }.tripToolbarBackground()
                    }
                }
            }
            .task { await store.refresh() }
            .task(id: copiedAmount) {
                if copiedAmount {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if !Task.isCancelled { copiedAmount = false }
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
        }
    }

    private func featureTile(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 26, weight: .regular)).foregroundStyle(.blue)
                Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }.padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.15)))
        }.buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func amountCard(source: Bool) -> some View {
        let code = source ? store.source : store.target
        return VStack(alignment: .leading, spacing: 6) {
            currencyButton(code, side: source ? .source : .target)
            if !source {
                Rectangle().fill(Color.blue.opacity(0.35)).frame(height: 1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Currency.named(code).symbol)
                    .font(.title2.weight(.medium)).foregroundStyle(.secondary)
                    .fixedSize().accessibilityHidden(true)
                TextField("Amount", text: Binding(
                    get: { store.fieldText(for: source ? .source : .target,
                                           focused: editingSide == (source ? .source : .target)) },
                    set: { store.edit($0, side: source ? .source : .target) }
                ))
                .font(.system(size: 28, weight: source ? .medium : .semibold))
                .monospacedDigit().keyboardType(.decimalPad)
                .focused($editingSide, equals: source ? .source : .target)
                .accessibilityLabel("\(source ? "From" : "To") amount in \(Currency.named(code).name)")
                if !source {
                    Button {
                        UIPasteboard.general.string = Currency.named(code).symbol + " " + store.result(for: code) + " " + code
                        copiedAmount = true
                    } label: {
                        Image(systemName: copiedAmount ? "checkmark" : "doc.on.doc")
                            .font(.subheadline).foregroundStyle(.blue).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).disabled(store.value(for: code) == nil)
                        .accessibilityLabel(copiedAmount ? "Amount copied" : "Copy converted amount")
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .foregroundStyle(Color.readable(on: boxColor))
        .background(Color(hex: boxColor),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var rateDetails: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                if !store.amount.isEmpty { Text(store.detail) }
                if let checked = store.lastChecked { TripRefreshStamp(success: store.lastManualRefresh, fallback: checked) }
                TripRateStatus(store: store)
                if store.cacheWriteFailed { Text("Couldn’t save rates.") }
            }.font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button("Clear") { store.edit("", side: editingSide ?? store.inputSide) }
                .font(.caption).frame(minHeight: 44).accessibilityLabel("Clear amount")
            Button { Task { await store.refresh(force: true) } } label: {
                Group {
                    if store.isLoading { ProgressView() }
                    else { Image(systemName: "arrow.clockwise") }
                }.frame(width: 44, height: 44)
            }.disabled(store.isLoading).accessibilityLabel("Refresh rates")
        }
    }

    private var saveButtons: some View {
        HStack(spacing: 10) {
            Button { draft = store.savedDraft() } label: {
                Label("Save conversion", systemImage: "bookmark")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }.buttonStyle(TripButtonStyle(primary: true))
                .disabled(store.savedDraft() == nil || saved.loadError != nil)
            Button { showsSaved = true } label: {
                Text("Saved (\(saved.items.count))").frame(minHeight: 32)
            }.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle(radius: 8))
        }.font(.subheadline)
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Favorites").font(.subheadline.weight(.semibold))
                Spacer()
                Button { picker = .target } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }.font(.subheadline).frame(minHeight: 44)
            }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(store.favorites, id: \.self) { code in
                        Button { store.target = code } label: {
                            VStack(alignment: .leading, spacing: 2) {
                              HStack(spacing: 4) {
                                Text(code).font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Text("\(Currency.named(code).symbol) \(store.result(for: code))")
                                    .font(.subheadline.weight(.medium)).monospacedDigit()
                                    .lineLimit(1).minimumScaleFactor(0.65)
                              }
                                Text(Currency.named(code).countryLabel).font(.caption2)
                                    .foregroundStyle(.secondary).lineLimit(1)
                            }.frame(maxWidth: .infinity, minHeight: 36, alignment: .leading).padding(8)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(store.target == code ? Color.blue : Color.clear, lineWidth: 1.5))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Convert to \(Currency.named(code).name), \(store.result(for: code)) \(code)")
                            .accessibilityAddTraits(store.target == code ? [.isSelected] : [])
                    }
                }.padding(2)
            if store.favorites.isEmpty {
                Text("Star currencies in Search to keep them here.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func currencyButton(_ code: String, side: PickerSide) -> some View {
        Button { editingSide = nil; picker = side } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(side == .source ? "From" : "To").font(.caption).foregroundStyle(.secondary)
                        (Text(code).fontWeight(.semibold) + Text(" (\(Currency.named(code).name))"))
                            .font(.headline).lineLimit(1).minimumScaleFactor(0.65)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.blue)
                    .padding(.horizontal, 10).frame(minHeight: 44)
                    .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }.foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("\(side == .source ? "From" : "To"): \(Currency.named(code).name), \(Currency.named(code).countryLabel). Change currency")
    }

}

private struct ConverterPageLayout: Layout {
    let availableHeight: CGFloat
    let expandsCards: Bool
    private let spacing: CGFloat = 8

    private func heights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let naturalHeight = heights(width: width, subviews: subviews).reduce(0, +)
            + spacing * CGFloat(max(0, subviews.count - 1))
        return CGSize(width: width, height: expandsCards ? max(availableHeight, naturalHeight) : naturalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var sizes = heights(width: bounds.width, subviews: subviews)
        let naturalHeight = sizes.reduce(0, +) + spacing * CGFloat(max(0, sizes.count - 1))
        if expandsCards, !sizes.isEmpty { sizes[0] += max(0, bounds.height - naturalHeight) }
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: sizes[index]))
            y += sizes[index] + spacing
        }
    }
}

struct CurrencyPicker: View {
    @ObservedObject var store: ConverterStore
    let title: String
    let select: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    private var results: [Currency] {
        query.trimmingCharacters(in: .whitespaces).isEmpty ? [] : Currency.all.filter { $0.matches(query) }.sorted { $0.name < $1.name }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { currency in
                    HStack {
                        Button { select(currency.code) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currency.code).font(.headline)
                                Text(currency.name).font(.subheadline).foregroundStyle(.secondary)
                                Text(currency.countryLabel(matching: query)).font(.headline)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)

                    }
                }
                if results.isEmpty { Text(query.isEmpty ? "Search for a country, currency, or code." : "No currency found. Try a country name, currency name or three-letter code.").foregroundStyle(.secondary) }
            }.searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Country, currency or code")
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { TripNavigationButton(title: "Done") { dismiss() } }.tripToolbarBackground() }
        }
    }
}
