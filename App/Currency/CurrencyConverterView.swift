import SwiftUI

private enum PickerSide: String, Identifiable { case source, target; var id: String { rawValue } }

struct CurrencyConverterView: View {
    @ObservedObject var store: ConverterStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var picker: PickerSide?
    @State private var showsAbout = false
    @StateObject private var saved = SavedConversions()
    @State private var draft: SavedConversion?
    @State private var showsSaved = false
    @State private var showsItems = false
    @State private var showsPhotoPrices = false
    @AppStorage("trip-currency-color") private var boxColor = "F3F3F3"
    @FocusState private var editingSide: AmountSide?
    private var editing: Bool { editingSide != nil }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
              ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        VStack(spacing: 6) {
                            amountCard(source: true)
                            Button { editingSide = nil; store.swap() } label: {
                                Image(systemName: "arrow.up.arrow.down").font(.title3).frame(width: 44, height: 44)
                            }.buttonStyle(.bordered).accessibilityLabel("Swap currencies")
                            amountCard(source: false)
                            HStack { Spacer(); Button("Clear amount") { store.edit("", side: editingSide ?? store.inputSide) }.font(.caption) }
                            rateDetails
                        }.tripPanel().id("amounts")

                        if !editing {
                            HStack(spacing: 10) {
                                featureTile("Add multiple prices", detail: "Convert their total.", icon: "list.bullet.rectangle") { showsItems = true }
                                featureTile("Live camera / photo", detail: "Read and convert prices.", icon: "camera.viewfinder") { showsPhotoPrices = true }
                            }
                            saveButtons
                            TripArtwork(symbol: "banknote")
                            VStack(spacing: 0) {
                                Text("Reference rates by Frankfurter · Bank and card rates may differ.")
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                                Button("About rates & privacy") { showsAbout = true }
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .accessibilityLabel("About exchange rates and privacy")
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: editing) { _, active in
                    if active { proxy.scrollTo("amounts", anchor: .top) }
                }
            }
            }
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Convert") { editingSide = nil } }
            }
            .sheet(item: $picker) { side in CurrencyPicker(store: store, title: side == .target ? "Search currency" : "Convert from", select: { code in
                if side == .source { store.source = code } else { store.target = code }; picker = nil
            }) }
            .sheet(isPresented: $showsItems) { NavigationStack { ItemConversionView(store: store) } }
            .sheet(isPresented: $showsPhotoPrices) { NavigationStack { PriceImageView(store: store).toolbar { Button("Done") { showsPhotoPrices = false } } } }
            .sheet(isPresented: $showsAbout) { about }
            .sheet(item: $draft) { entry in SaveConversionView(draft: entry, saved: saved) }
            .sheet(isPresented: $showsSaved) { SavedConversionsView(saved: saved) }
            .task { await store.refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
        }
    }

    private func featureTile(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 42, weight: .regular)).foregroundStyle(.blue)
                Text(title).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.65)
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }.padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.blue.opacity(0.15)))
        }.buttonStyle(.plain).frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
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
                .font(.system(size: editing ? 32 : 36, weight: source ? .medium : .semibold))
                .monospacedDigit().keyboardType(.decimalPad)
                .focused($editingSide, equals: source ? .source : .target)
                .accessibilityLabel("\(source ? "From" : "To") amount in \(Currency.named(code).name)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .foregroundStyle(Color.readable(on: boxColor))
        .background(Color(hex: boxColor),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var rateDetails: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.detail)
                if let checked = store.lastChecked { Text(checked) }
                if store.updateFailed {
                    Label(store.snapshot == nil ? "Couldn’t load rates. Try again when connected." : "Couldn’t refresh. Showing saved rates.", systemImage: "wifi.slash")
                }
                if store.cacheWriteFailed { Text("Rates loaded, but couldn’t save for offline use.") }
            }.font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
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
            }.buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 8))
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

    private var about: some View {
        NavigationStack {
            List {
                Section("Exchange rates") {
                    Text("Daily reference rates from Frankfurter. These are estimates, not guaranteed transaction prices. Different currencies can have different rate dates; both dates appear when needed. Last checked shows when this device last downloaded rates, in your local time zone. The provider supplies a rate date, not an exact publication time.")
                    Link("Frankfurter and data sources", destination: URL(string: "https://frankfurter.dev/")!)
                    Link("Provider terms", destination: URL(string: "https://frankfurter.dev/license/")!)
                }
                Section("Offline use") { Text("After a successful update, rates are saved on this iPhone. Refresh requires internet. Older rates stay clearly dated.") }
                Section("Privacy") { Text("No account, ads, or analytics. Your amount, favorites, saved conversions, notes and attached photos are stored locally and may be included in your device backups. The app does not upload notes or photos. Camera access is used only when you choose Take photo; Photos lets you select an individual image. The app requests a USD rate table over HTTPS; it does not send your entered amount. The rate service and network infrastructure process the request.") }
                Section("Currency search") { Text("Search the full travel currency catalogue by country, currency name or code. Favorites appear first. Croatia uses EUR; Tahiti and Bora Bora use XPF. Availability depends on the rate provider; unavailable conversions show a dash.") }
            }.navigationTitle("About").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsAbout = false } } }
        }
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
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
