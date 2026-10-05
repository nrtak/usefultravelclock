import Foundation
import SwiftUI

enum AmountSide: String { case source, target }

@MainActor
final class ConverterStore: ObservableObject {
    @Published var source: String { didSet { preferences.set(source, forKey: "source") } }
    @Published var target: String { didSet { preferences.set(target, forKey: "target") } }
    @Published var favorites: [String] { didSet { preferences.set(favorites, forKey: "favorites") } }
    @Published var amount: String { didSet { preferences.set(amount, forKey: "amount") } }
    @Published private(set) var inputSide: AmountSide { didSet { preferences.set(inputSide.rawValue, forKey: "inputSide") } }
    @Published private(set) var snapshot: RateSnapshot?
    @Published private(set) var usingBundledRates = false
    @Published private(set) var isLoading = false
    @Published private(set) var updateFailed = false
    @Published private(set) var cacheWriteFailed = false
    @Published var multiplePriceItems = [ItemPrice()]
    @Published private(set) var lastManualRefresh: Date?
    private let preferences: UserDefaults
    private let cacheURL: URL
    private let service: any RateService
    private let isOffline: @MainActor () -> Bool

    init(preferences: UserDefaults = .standard, cacheURL: URL? = nil, service: any RateService = FrankfurterService(), isOffline: @escaping @MainActor () -> Bool = { TripConnectionStore.shared.isOffline }) {
        self.preferences = preferences
        self.service = service
        self.isOffline = isOffline
        self.cacheURL = cacheURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SimpleCurrency/rates-v1.json")
        let codes = Set(Currency.all.map(\.code))
        let savedSource = preferences.string(forKey: "source") ?? "USD"
        let savedTarget = preferences.string(forKey: "target") ?? "EUR"
        source = codes.contains(savedSource) ? savedSource : "USD"
        target = codes.contains(savedTarget) ? savedTarget : "EUR"
        amount = preferences.string(forKey: "amount") ?? "100"
        inputSide = AmountSide(rawValue: preferences.string(forKey: "inputSide") ?? "source") ?? .source
        var seen = Set<String>()
        favorites = (preferences.stringArray(forKey: "favorites") ?? ["EUR", "JPY", "GBP", "CAD"])
            .filter { codes.contains($0) && seen.insert($0).inserted }
        if let data = try? Data(contentsOf: self.cacheURL), let cache = try? JSONDecoder().decode(RateSnapshot.self, from: data) {
            snapshot = cache
        } else if cacheURL == nil, let url = Bundle.main.url(forResource: "BundledRates", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let rows = try? JSONDecoder().decode([Rate].self, from: data), !rows.isEmpty {
            snapshot = RateSnapshot(fetchedAt: Date(timeIntervalSince1970: 1791238680), rows: rows)
            usingBundledRates = true
        }
    }

    var result: String {
        result(for: target)
    }

    func result(for code: String) -> String {
        guard let value = value(for: code) else { return "—" }
        return Amount.format(value, currency: .named(code))
    }

    func value(for code: String) -> Decimal? {
        guard let value = Amount.parse(amount) else { return nil }
        let inputCode = inputSide == .source ? source : target
        if inputCode == code { return value }
        guard let multiplier = snapshot?.multiplier(from: inputCode, to: code) else { return nil }
        return value * multiplier
    }

    func edit(_ text: String, side: AmountSide) {
        inputSide = side
        amount = text
    }

    func fieldText(for side: AmountSide, focused: Bool) -> String {
        if side == inputSide { return amount }
        let code = side == .source ? source : target
        guard let value = value(for: code) else { return "" }
        let formatted = Amount.format(value, currency: .named(code))
        return focused ? formatted.replacingOccurrences(of: Locale.current.groupingSeparator ?? ",", with: "") : formatted
    }

    var detail: String {
        guard Amount.parse(amount) != nil else { return "Enter a positive amount or zero, without grouping separators." }
        if source == target { return "Same currency · No conversion needed" }
        guard let snapshot, snapshot.multiplier(from: source, to: target) != nil else {
            return isLoading ? "Getting exchange rates…" : "Rate unavailable. Connect and tap Refresh."
        }
        let dates = snapshot.dates(from: source, to: target)
        let stamp = dates.joined(separator: " / ")
        let oldest = dates.first.flatMap(RateSnapshot.validDate)
        let stale = oldest.map { Date().timeIntervalSince($0) > 4 * 86400 } ?? true
        return (usingBundledRates ? "Bundled reference rates as of " : "Reference rates as of ") + stamp + (stale ? " · Older rates" : "")
    }

    var lastChecked: String? {
        guard let snapshot else { return nil }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let zone = TimeZone.current.abbreviation() ?? TimeZone.current.identifier
        return (usingBundledRates ? "Included rate snapshot retrieved " : "Rates last retrieved ") + formatter.string(from: snapshot.fetchedAt) + " " + zone
    }

    func savedDraft() -> SavedConversion? {
        guard let sourceValue = value(for: source), let converted = value(for: target),
              let multiplier = source == target ? Decimal(1) : snapshot?.multiplier(from: source, to: target) else { return nil }
        return SavedConversion(id: UUID(), savedAt: Date(), source: source, target: target,
                               amount: sourceValue, multiplier: multiplier, convertedAmount: converted,
                               rateDates: source == target ? [] : snapshot?.dates(from: source, to: target) ?? [],
                               ratesCheckedAt: source == target ? nil : snapshot?.fetchedAt,
                               note: "", photoFilename: nil)
    }

    func swap() {
        let old = source
        source = target
        target = old
        inputSide = inputSide == .source ? .target : .source
    }
    func toggleFavorite(_ code: String) {
        if favorites.contains(code) { favorites.removeAll { $0 == code } } else { favorites.append(code) }
    }

    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        if !force, let snapshot, (0..<(12 * 3600)).contains(Date().timeIntervalSince(snapshot.fetchedAt)), !updateFailed { return }
        guard !isOffline() else { updateFailed = true; return }
        isLoading = true
        if force { lastManualRefresh = nil }
        defer { isLoading = false }
        do {
            let fresh = try await service.fetch()
            var combined = Dictionary((snapshot?.rows ?? []).map { ($0.quote, $0) }, uniquingKeysWith: { a, b in a.date >= b.date ? a : b })
            for row in fresh.rows {
                if let old = combined[row.quote], old.date > row.date { continue }
                combined[row.quote] = row
            }
            let next = RateSnapshot(fetchedAt: fresh.fetchedAt, rows: combined.values.sorted { $0.quote < $1.quote })
            snapshot = next
            usingBundledRates = false
            updateFailed = false
            if force { lastManualRefresh = Date() }
            do {
                try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(next).write(to: cacheURL, options: .atomic)
                cacheWriteFailed = false
            } catch { cacheWriteFailed = true }
        } catch { updateFailed = true }
    }
}
