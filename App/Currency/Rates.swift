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
}

enum Amount {
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let normalized = trimmed.replacingOccurrences(of: separator, with: ".")
        guard !normalized.isEmpty, normalized.count <= 18,
              normalized.filter({ $0 == "." }).count <= 1,
              normalized.allSatisfy({ "0123456789.".contains($0) }),
              normalized.contains(where: { "0123456789".contains($0) }) else { return nil }
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func format(_ amount: Decimal, currency: Currency, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
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
