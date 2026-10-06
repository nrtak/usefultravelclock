import Foundation

struct Currency: Identifiable, Hashable {
    let code: String
    let name: String
    let aliases: String
    var id: String { code }
    var symbol: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let value = formatter.currencySymbol ?? code
        return value == code ? (Self.catalogue.first { $0.code == code }?.symbol ?? code) : value
    }
    private struct CatalogueEntry: Decodable {
        let code: String
        let name: String
        let symbol: String?
    }
    private static let catalogue: [CatalogueEntry] = {
        guard let url = Bundle.main.url(forResource: "Currencies", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([CatalogueEntry].self, from: data) else { return [] }
        return rows
    }()
    var countries: [String] { Self.countryNames[code] ?? [] }
    var countryLabel: String {
        switch code {
        case "EUR": return "Eurozone"
        case "XAF": return "Central Africa"
        case "XOF": return "West Africa"
        case "XCD": return "Eastern Caribbean"
        default: return Self.preferredCountryNames[code]?.first ?? countries.first ?? name
        }
    }
    func countryLabel(matching query: String) -> String {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return countryLabel }
        let matches = countries.filter { $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return matches.isEmpty ? countryLabel : matches.joined(separator: " · ")
    }
    var fractionDigits: Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }

    func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: { $0.isWhitespace })
        let text = "\(code) \(name) \(aliases) \(countries.joined(separator: " "))"
        return terms.allSatisfy { text.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    static func named(_ code: String) -> Currency { all.first { $0.code == code } ?? Currency(code: code, name: Locale(identifier: "en_US").localizedString(forCurrencyCode: code) ?? code, aliases: "") }
    static let countryNames: [String: [String]] = {
        var result = preferredCountryNames
        let english = Locale(identifier: "en_US")
        for region in Locale.Region.isoRegions {
            let locale = Locale(identifier: "en_" + region.identifier)
            guard let code = locale.currency?.identifier,
                  let name = english.localizedString(forRegionCode: region.identifier) else { continue }
            if !(result[code] ?? []).contains(name) { result[code, default: []].append(name) }
        }
        result["GGP"] = ["Guernsey"]
        result["JEP"] = ["Jersey"]
        result["IMP"] = ["Isle of Man"]
        result["XCG"] = ["Curaçao", "Sint Maarten"]
        result["ZWG"] = ["Zimbabwe"]
        result["CNH"] = ["China (offshore)"]
        result["XAF"] = ["Cameroon", "Central African Republic", "Chad", "Republic of the Congo", "Equatorial Guinea", "Gabon"]
        result["XOF"] = ["Benin", "Burkina Faso", "Côte d’Ivoire", "Guinea-Bissau", "Mali", "Niger", "Senegal", "Togo"]
        result["XCD"] = ["Anguilla", "Antigua and Barbuda", "Dominica", "Grenada", "Montserrat", "Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines"]
        let regionCodes = Set(Locale.Region.isoRegions.map(\.identifier))
        for entry in catalogue where (result[entry.code] ?? []).isEmpty {
            let region = String(entry.code.prefix(2))
            if regionCodes.contains(region), let name = english.localizedString(forRegionCode: region) {
                result[entry.code] = [name]
            }
        }
        return result
    }()
    private static let preferredCountryNames: [String: [String]] = [
        "USD": ["United States"], "CAD": ["Canada"], "MXN": ["Mexico"],
        "EUR": ["Germany", "France", "Austria", "Belgium", "Bulgaria", "Croatia", "Cyprus", "Estonia", "Finland", "Greece", "Ireland", "Italy", "Latvia", "Lithuania", "Luxembourg", "Malta", "Netherlands", "Portugal", "Slovakia", "Slovenia", "Spain", "Andorra", "Monaco", "San Marino", "Vatican City", "Montenegro", "Kosovo"],
        "JPY": ["Japan"], "TWD": ["Taiwan"], "KRW": ["South Korea"],
        "HKD": ["Hong Kong"], "CNY": ["Mainland China"], "VND": ["Vietnam"],
        "GBP": ["United Kingdom"], "AED": ["United Arab Emirates"],
        "QAR": ["Qatar"], "SAR": ["Saudi Arabia"], "ILS": ["Israel"],
        "XPF": ["French Polynesia", "New Caledonia", "Wallis and Futuna"],
        "FJD": ["Fiji"], "BRL": ["Brazil"], "AUD": ["Australia"],
        "NZD": ["New Zealand"], "CHF": ["Switzerland", "Liechtenstein"],
        "SGD": ["Singapore"], "THB": ["Thailand"], "INR": ["India"],
        "PHP": ["Philippines"], "IDR": ["Indonesia"]
    ]
    static let all: [Currency] = {
        let excluded: Set<String> = ["ANG", "MRO", "SVC", "CMD", "XDR", "XAU", "XAG", "XPD", "XPT"]
        var entries = Dictionary(uniqueKeysWithValues: common.map { ($0.code, $0) })
        for entry in catalogue where !excluded.contains(entry.code) {
            if entries[entry.code] == nil {
                entries[entry.code] = Currency(code: entry.code, name: entry.name, aliases: alternateNames[entry.code] ?? "")
            }
        }
        return entries.values.sorted { $0.code < $1.code }
    }()
    private static let alternateNames: [String: String] = [
        "TRY": "Turkey Türkiye Turkish lira", "CZK": "Czech Republic Czechia",
        "SZL": "Swaziland Eswatini", "MMK": "Burma Myanmar",
        "CVE": "Cape Verde Cabo Verde", "XOF": "Ivory Coast Cote d Ivoire",
        "MOP": "Macau Macao", "SLE": "Sierra Leone", "STN": "Sao Tome Principe",
        "KRW": "South Korea", "KPW": "North Korea"
    ]
    private static let common: [Currency] = [
        .init(code: "USD", name: "US dollar", aliases: "USA United States America"),
        .init(code: "CAD", name: "Canadian dollar", aliases: "Canada"),
        .init(code: "MXN", name: "Mexican peso", aliases: "Mexico México"),
        .init(code: "EUR", name: "Euro", aliases: "Europe European Union EU Eurozone Croatia France Germany Italy Spain Portugal Austria Belgium Netherlands Ireland Greece Finland"),
        .init(code: "JPY", name: "Japanese yen", aliases: "Japan"),
        .init(code: "TWD", name: "New Taiwan dollar", aliases: "Taiwan"),
        .init(code: "KRW", name: "South Korean won", aliases: "South Korea"),
        .init(code: "HKD", name: "Hong Kong dollar", aliases: "Hong Kong"),
        .init(code: "CNY", name: "Chinese yuan", aliases: "Mainland China RMB renminbi"),
        .init(code: "VND", name: "Vietnamese dong", aliases: "Vietnam Việt Nam"),
        .init(code: "GBP", name: "Pound sterling", aliases: "United Kingdom UK Britain England Scotland Wales Northern Ireland"),
        .init(code: "AED", name: "UAE dirham", aliases: "United Arab Emirates Dubai Abu Dhabi"),
        .init(code: "QAR", name: "Qatari riyal", aliases: "Qatar"),
        .init(code: "SAR", name: "Saudi riyal", aliases: "Saudi Arabia"),
        .init(code: "ILS", name: "Israeli new shekel", aliases: "Israel"),
        .init(code: "XPF", name: "CFP franc", aliases: "French Polynesia Tahiti Bora Bora New Caledonia Wallis Futuna"),
        .init(code: "FJD", name: "Fiji dollar", aliases: "Fiji"),
        .init(code: "BRL", name: "Brazilian real", aliases: "Brazil Brasil"),
        .init(code: "AUD", name: "Australian dollar", aliases: "Australia"),
        .init(code: "NZD", name: "New Zealand dollar", aliases: "New Zealand"),
        .init(code: "CHF", name: "Swiss franc", aliases: "Switzerland Liechtenstein"),
        .init(code: "SGD", name: "Singapore dollar", aliases: "Singapore"),
        .init(code: "THB", name: "Thai baht", aliases: "Thailand"),
        .init(code: "INR", name: "Indian rupee", aliases: "India"),
        .init(code: "PHP", name: "Philippine peso", aliases: "Philippines"),
        .init(code: "IDR", name: "Indonesian rupiah", aliases: "Indonesia Bali")
    ]
}
