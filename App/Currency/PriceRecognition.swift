import Foundation

struct RecognizedPrice: Identifiable {
    let id = UUID()
    let value: Decimal
}

enum PriceRecognition {
    // Require price context. Bare integers could be product IDs, quantities or dates.
    // Do not guess digits from letters such as O, I, S or B.
    static func read(_ text: String, currency: Currency, includeUnmarked: Bool = false) -> [RecognizedPrice] {
        let text = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let excluded = #"(?i)(商品番号|品番|型番|電話|SKU|ISBN|product\s*(?:no|number|id)|item\s*(?:no|number|id)|model|order\s*(?:no|number|id)|phone)"#
        let symbols = currency.code == "JPY" ? [currency.symbol, "¥", "円"] : [currency.symbol]
        let markers = Array(Set(symbols + [currency.code])).filter { !$0.isEmpty }
            .map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        let number = #"([0-9][0-9.,]*[0-9]|[0-9])"#
        let patterns = [
            "(?i)(?<![\\p{L}\\p{N}])(?:" + markers + ")\\s*" + number + "(?![\\p{L}\\p{N}.,])",
            "(?i)(?<![\\p{L}\\p{N}.,])" + number + "\\s*(?:" + markers + ")(?![\\p{L}\\p{N}])",
            "(?i)(?:price|total|amount|価格|税込|合計)\\s*[:：]?\\s*" + number + "(?![\\p{L}\\p{N}.,])"
        ]
        var output: [RecognizedPrice] = []
        for line in text.components(separatedBy: .newlines) {
            guard line.range(of: excluded, options: .regularExpression) == nil else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if includeUnmarked, let value = parseNumber(trimmed) {
                output.append(RecognizedPrice(value: value))
                continue
            }
            var matches: [(NSRange, Decimal)] = []
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                for match in regex.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
                    guard let range = Range(match.range(at: 1), in: line),
                          let value = parseNumber(String(line[range])),
                          !matches.contains(where: { NSIntersectionRange($0.0, match.range).length > 0 }) else { continue }
                    matches.append((match.range, value))
                }
            }
            output += matches.sorted { $0.0.location < $1.0.location }.map { RecognizedPrice(value: $0.1) }
        }
        return output
    }

    static func parseNumber(_ text: String) -> Decimal? {
        let patterns = [
            (#"^[0-9]+(?:\.[0-9]{1,2})?$"#, ",", "."),
            (#"^[0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?$"#, ",", "."),
            (#"^[0-9]+,[0-9]{1,2}$"#, ".", ","),
            (#"^[0-9]{1,3}(?:\.[0-9]{3})+(?:,[0-9]{1,2})?$"#, ".", ",")
        ]
        for (pattern, grouping, decimal) in patterns where text.range(of: pattern, options: .regularExpression) != nil {
            let normalized = text.replacingOccurrences(of: grouping, with: "").replacingOccurrences(of: decimal, with: ".")
            return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
}
