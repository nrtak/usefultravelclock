import SwiftUI
import Translation

enum TranslationLanguageLabel {
    static func name(_ code: String, locale: Locale = .current) -> String {
        let normalized = code.replacingOccurrences(of: "_", with: "-").lowercased()
        let name = locale.localizedString(forIdentifier: code) ?? code
        // A language-only identifier does not specify a country or dialect.
        return normalized == "en" || normalized == "en-latn" ? name + " (General)" : name
    }
}

enum TranslationLanguageSide: String, Identifiable {
    case source, target
    var id: String { rawValue }
}

struct TranslationLanguagePicker: View {
    @Binding var selection: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var languages: [String] = []
    @State private var loading = true

    private func name(_ code: String, locale: Locale = .current) -> String {
        TranslationLanguageLabel.name(code, locale: locale)
    }
    private var results: [String] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return languages.filter { code in
            term.isEmpty || [code, name(code), name(code, locale: Locale(identifier: code)), name(code, locale: Locale(identifier: "en"))]
                .contains { $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView("Loading languages…") }
                ForEach(results, id: \.self) { code in
                    Button {
                        selection = code
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name(code)).foregroundStyle(.primary)
                                Text(name(code, locale: Locale(identifier: code))).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if Locale.Language(identifier: code).isEquivalent(to: Locale.Language(identifier: selection)) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                if !loading && results.isEmpty {
                    Text(languages.isEmpty ? "No translation languages are available on this device." : "No matching language. Try its name or language code.")
                        .foregroundStyle(.secondary)
                }
                if !loading { Text("English (General) has no country specified. Languages are provided by Apple; a download may be needed.").font(.caption).foregroundStyle(.secondary) }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search languages")
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { TripActionButton("Cancel", primary: false) { dismiss() } }.tripToolbarBackground() }
            .task {
                let supported = await LanguageAvailability().supportedLanguages
                languages = Array(Set(supported.map(\.minimalIdentifier))).sorted { name($0).localizedStandardCompare(name($1)) == .orderedAscending }
                loading = false
            }
        }
    }
}
