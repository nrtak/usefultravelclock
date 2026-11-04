import Foundation

struct Rate: Codable, Equatable {
    let date: String
    let base: String
    let quote: String
    let rate: Decimal
}

struct RateSnapshot: Codable {
    let fetchedAt: Date
    let rows: [Rate]

    static func validDate(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        guard let date = formatter.date(from: text), formatter.string(from: date) == text else { return nil }
        return date
    }

    func row(_ code: String) -> Rate? {
        rows.filter { $0.base == "USD" && $0.quote == code && $0.rate > 0 && Self.validDate($0.date) != nil }
            .max { $0.date < $1.date }
    }

    func multiplier(from: String, to: String) -> Decimal? {
        if from == to { return 1 }
        guard let a: Decimal = from == "USD" ? 1 : row(from)?.rate,
              let b: Decimal = to == "USD" ? 1 : row(to)?.rate else { return nil }
        return b / a
    }

    func dates(from: String, to: String) -> [String] {
        Array(Set([from, to].filter { $0 != "USD" }.compactMap { row($0)?.date })).sorted()
    }
    func needsRefresh(from: String, to: String, now: Date = Date()) -> Bool {
        guard from != to else { return false }
        guard multiplier(from: from, to: to) != nil else { return true }
        let dates = dates(from: from, to: to).compactMap(Self.validDate)
        guard !dates.isEmpty else { return true }
        // Check both legs of a cross-currency conversion, including future dates.
        return dates.contains { date in
            let age = now.timeIntervalSince(date)
            return age < 0 || age >= 7 * 86400
        }
    }
}

enum Amount {
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let grouping = locale.groupingSeparator ?? ","
        let parts = trimmed.components(separatedBy: separator)
        guard parts.count <= 2 else { return nil }
        if grouping != separator && trimmed.contains(grouping) {
            // Validate grouping before stripping it: "1,234" is valid English
            // input, while "12,34" must not silently become a different amount.
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            let primary = formatter.groupingSize > 0 ? formatter.groupingSize : 3
            let secondary = formatter.secondaryGroupingSize > 0 ? formatter.secondaryGroupingSize : primary
            let groups = parts[0].components(separatedBy: grouping)
            guard groups.count > 1, groups.last?.count == primary,
                  (1...secondary).contains(groups[0].count),
                  groups.dropFirst().dropLast().allSatisfy({ $0.count == secondary }),
                  groups.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ "0123456789".contains($0) }) }),
                  parts.count == 1 || !parts[1].contains(grouping) else { return nil }
        }
        let ungrouped = grouping == separator ? trimmed : trimmed.replacingOccurrences(of: grouping, with: "")
        let normalized = ungrouped.replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty, normalized.count <= 18,
              normalized.filter({ $0 == "." }).count <= 1,
              normalized.allSatisfy({ "0123456789.".contains($0) }),
              normalized.contains(where: { "0123456789".contains($0) }) else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func editableInput(_ text: String, locale: Locale = .current) -> String {
        guard parse(text, locale: locale) != nil else { return text }
        let grouping = locale.groupingSeparator ?? ","
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return grouping == locale.decimalSeparator ? trimmed : trimmed.replacingOccurrences(of: grouping, with: "")
    }

    // Group the display without changing stored input, decimal precision or the
    // cursor position while typing. Respect locales with a different grouping size.
    static func groupedInput(_ text: String, locale: Locale = .current) -> String {
        guard parse(text, locale: locale) != nil else { return text }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let decimal = locale.decimalSeparator ?? "."
        let parts = editableInput(text, locale: locale).components(separatedBy: decimal)
        var remaining = parts[0][...]
        var groups: [String] = []
        var size = formatter.groupingSize > 0 ? formatter.groupingSize : 3
        let secondary = formatter.secondaryGroupingSize > 0 ? formatter.secondaryGroupingSize : size
        while remaining.count > size {
            groups.insert(String(remaining.suffix(size)), at: 0)
            remaining = remaining.dropLast(size)
            size = secondary
        }
        groups.insert(String(remaining), at: 0)
        return groups.joined(separator: locale.groupingSeparator ?? ",") + (parts.count == 2 ? decimal + parts[1] : "")
    }

    static func format(_ amount: Decimal, currency: Currency, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = currency.fractionDigits
        formatter.maximumFractionDigits = currency.fractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—"
    }
}

protocol RateService {
    func fetch() async throws -> RateSnapshot
}

struct FrankfurterService: RateService {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func fetch() async throws -> RateSnapshot {
        var request = URLRequest(url: URL(string: "https://api.frankfurter.dev/v2/rates?base=USD")!)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let rows = try JSONDecoder().decode([Rate].self, from: data)
        let valid = rows.filter { $0.base == "USD" && $0.rate > 0 && RateSnapshot.validDate($0.date) != nil }
        guard !valid.isEmpty else { throw URLError(.cannotParseResponse) }
        return RateSnapshot(fetchedAt: Date(), rows: valid)
    }
}
