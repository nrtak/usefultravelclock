import SwiftUI
import PhotosUI

struct SavedUnitConversion: Codable, Identifiable {
    var id = UUID()
    var date = Date()
    let source: String
    let target: String
    let sourceValue: Double
    let targetValue: Double
    let note: String
    let image: Data?
}
@MainActor final class UnitConversionStore: ObservableObject {
    @Published private(set) var entries: [SavedUnitConversion] = []
    @Published var error: String?
    private var loadFailed = false
    private let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TripNotes/unit-conversions.json")
        do { if FileManager.default.fileExists(atPath: self.url.path) { entries = try JSONDecoder().decode([SavedUnitConversion].self, from: Data(contentsOf: self.url)) } }
        catch { loadFailed = true; self.error = "Couldn’t read saved conversions. Existing data was kept." }
    }
    func save(_ entry: SavedUnitConversion) -> Bool { persist([entry] + entries) }
    @Published private(set) var canUndo = false
    private var removed: [(Int, SavedUnitConversion)] = []
    func remove(at offsets: IndexSet) {
        let valid = offsets.filter { entries.indices.contains($0) }
        let deleted = valid.map { ($0, entries[$0]) }
        guard !deleted.isEmpty else { return }
        var next = entries; next.remove(atOffsets: IndexSet(valid))
        if persist(next) { removed = deleted; canUndo = true }
    }
    func undoDelete() {
        var next = entries
        for (index, entry) in removed.sorted(by: { $0.0 < $1.0 }) where !next.contains(where: { $0.id == entry.id }) {
            next.insert(entry, at: min(index, next.count))
        }
        if persist(next) { removed = []; canUndo = false }
    }
    private func persist(_ next: [SavedUnitConversion]) -> Bool {
        guard !loadFailed else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: [.atomic, .completeFileProtection])
            entries = next; error = nil; return true
        } catch { self.error = "Couldn’t save on this device. Try again."; return false }
    }
}
struct TripUnitsView: View {
    @StateObject private var saved = UnitConversionStore()
    @AppStorage("trip-unit-category") private var category: UnitCategory = .distance
    @AppStorage("trip-unit-source") private var source = "mi"
    @AppStorage("trip-unit-target") private var target = "km"
    @State private var amount = "10"
    @State private var inputSource = true
    @State private var pickerSource: Bool?
    @State private var showPicker = false
    @State private var showSaved = false
    @State private var showScanner = false
    @State private var note = ""
    @State private var image: Data?
    @State private var photo: PhotosPickerItem?
    @State private var message = ""
    @FocusState private var focusSource: Bool?
    private func value(sourceSide: Bool) -> Double? {
        guard let number = UnitConversion.parse(amount) else { return nil }
        return UnitConversion.convert(number, from: .named(inputSource ? source : target), to: .named(sourceSide ? source : target))
    }
    private func field(_ sourceSide: Bool) -> Binding<String> {
        Binding(get: { inputSource == sourceSide ? amount : value(sourceSide: sourceSide).map { UnitConversion.format($0, grouping: focusSource != sourceSide) } ?? "" }, set: { amount = $0; inputSource = sourceSide })
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(UnitCategory.allCases) { kind in
                        Button { select(kind) } label: {
                            Label(kind.rawValue, systemImage: kind.icon).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, minHeight: 36)
                        }.buttonStyle(.bordered).tint(category == kind ? .blue : .gray)
                    }
                }
                HStack(spacing: 8) {
                    Button { focusSource = inputSource } label: { Label("Text", systemImage: "keyboard").font(.caption).frame(maxWidth: .infinity, minHeight: 32) }.buttonStyle(.bordered)
                    Button { focusSource = nil; showScanner = true } label: { Label("Live camera", systemImage: "camera.viewfinder").font(.caption).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, minHeight: 32) }.buttonStyle(.borderedProminent)
                    PhotosPicker(selection: $photo, matching: .images) { Label("Photo", systemImage: "photo").font(.caption).frame(maxWidth: .infinity, minHeight: 32) }.buttonStyle(.bordered)
                }
                VStack(spacing: 6) {
                    amountBox(true)
                    Button { let old = source; source = target; target = old; inputSource.toggle(); focusSource = nil } label: { Image(systemName: "arrow.up.arrow.down").frame(width: 44, height: 36) }.buttonStyle(.bordered).accessibilityLabel("Swap units")
                    amountBox(false)
                    HStack { Text("Edit either value to convert both ways.").font(.caption2).foregroundStyle(.secondary); Spacer(); Button("Clear") { amount = ""; note = ""; image = nil; message = "" }.font(.caption) }
                }.tripPanel()
                if let image, let ui = UIImage(data: image) {
                    HStack { Image(uiImage: ui).resizable().scaledToFit().frame(width: 60, height: 50); Text("Attached photo").font(.caption); Spacer(); Button("Remove") { self.image = nil }.font(.caption) }
                }
                TextField("Notes (optional)", text: $note, axis: .vertical).lineLimit(1...2).textFieldStyle(.roundedBorder)
                HStack {
                    Button {
                        guard let from = value(sourceSide: true), let to = value(sourceSide: false) else { return }
                        if saved.save(SavedUnitConversion(source: source, target: target, sourceValue: from, targetValue: to, note: note, image: image)) { message = "Saved on this device" }
                    } label: { Label("Save conversion", systemImage: "bookmark").font(.subheadline).frame(maxWidth: .infinity, minHeight: 36) }.buttonStyle(TripButtonStyle(primary: true)).disabled(value(sourceSide: true) == nil || value(sourceSide: false) == nil)
                    Button("Saved (\(saved.entries.count))") { showSaved = true }.buttonStyle(.bordered)
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
                if let error = saved.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(12)
        }.scrollBounceBehavior(.basedOnSize).navigationTitle("Unit Converter").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) { UnitSearchView(category: category, selected: pickerSource == true ? source : target) { unit in if pickerSource == true { source = unit.id } else { target = unit.id }; showPicker = false } }
        .sheet(isPresented: $showScanner) { UnitReadingView { reading in apply(reading); showScanner = false } }
        .sheet(isPresented: $showSaved) { NavigationStack { List {
            ForEach(saved.entries) { entry in
                NavigationLink {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(summary(entry)).font(.title2)
                        Text(entry.date.formatted()).font(.caption).foregroundStyle(.secondary)
                        Text(entry.note).textSelection(.enabled)
                        if let data = entry.image, let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 260) }
                        Spacer()
                    }.padding().navigationTitle("Saved conversion")
                } label: { VStack(alignment: .leading) { Text(summary(entry)); Text(entry.note).font(.caption).lineLimit(2) } }
            }.onDelete { saved.remove(at: $0) }
        }.overlay { if saved.entries.isEmpty { ContentUnavailableView("No saved conversions", systemImage: "bookmark") } }
            .safeAreaInset(edge: .bottom) {
                if saved.canUndo {
                    HStack { Text("Conversion deleted").font(.subheadline); Spacer(); Button("Undo") { saved.undoDelete() }.buttonStyle(TripButtonStyle()) }.padding().background(Color(.secondarySystemBackground))
                }
            }.navigationTitle("Saved units").toolbar { TripNavigationButton(title: "Done") { showSaved = false } } } }
        .onChange(of: photo) { _, item in
            Task {
                do {
                    guard let raw = try await item?.loadTransferable(type: Data.self), let cleaned = ConversionPhoto.jpeg(from: raw) else { return }
                    image = cleaned
                    let text = try await ImageText.read(cleaned).map(\.text).joined(separator: "\n")
                    let readings = UnitConversion.readings(text)
                    pendingReadings = readings; recognizedText = text; showPhotoReview = true
                } catch { message = "Couldn’t read this photo. Try a clearer image." }
            }
        }
        .sheet(isPresented: $showPhotoReview) { UnitPhotoReview(readings: pendingReadings, text: recognizedText) { apply($0); showPhotoReview = false } }
    }
    @State private var pendingReadings: [UnitConversion.Reading] = []
    @State private var recognizedText = ""
    @State private var showPhotoReview = false
    private func amountBox(_ sourceSide: Bool) -> some View {
        let unit = TravelUnit.named(sourceSide ? source : target)
        return VStack(spacing: 6) {
            Button { focusSource = nil; pickerSource = sourceSide; showPicker = true } label: {
                HStack { Text(sourceSide ? "From" : "To").font(.caption).foregroundStyle(.secondary); Text(unit.name).font(.headline).lineLimit(1).minimumScaleFactor(0.6); Spacer(); Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Change \(sourceSide ? "source" : "target") unit")
            HStack { TextField("Amount", text: field(sourceSide)).keyboardType(category == .temperature ? .numbersAndPunctuation : .decimalPad).focused($focusSource, equals: sourceSide).font(.system(size: 32, weight: .semibold)).monospacedDigit(); Text(unit.symbol).foregroundStyle(.secondary) }
        }.padding(8).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    private func select(_ kind: UnitCategory) {
        category = kind; let units = TravelUnit.all.filter { $0.category == kind }; source = units[0].id; target = units[1].id; amount = ""; inputSource = true; focusSource = nil
    }
    private func apply(_ reading: UnitConversion.Reading) {
        if category != reading.unit.category { select(reading.unit.category) }
        source = reading.unit.id
        if target == source { target = TravelUnit.all.first { $0.category == category && $0.id != source }!.id }
        inputSource = true; amount = UnitConversion.format(reading.value); message = "Recognized \(reading.text). Review before saving."
    }
    private func summary(_ entry: SavedUnitConversion) -> String { "\(UnitConversion.format(entry.sourceValue, grouping: true)) \(TravelUnit.named(entry.source).symbol) ↔ \(UnitConversion.format(entry.targetValue, grouping: true)) \(TravelUnit.named(entry.target).symbol)" }
}
struct UnitSearchView: View {
    let category: UnitCategory
    let selected: String
    let select: (TravelUnit) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { List(TravelUnit.all.filter { $0.category == category && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.symbol.localizedCaseInsensitiveContains(query)) }) { unit in
        Button { select(unit) } label: { HStack { Text(unit.name); Spacer(); Text(unit.symbol).foregroundStyle(.secondary); if unit.id == selected { Image(systemName: "checkmark") } } }
    }.searchable(text: $query, prompt: "Search units").navigationTitle("Choose unit").toolbar { TripActionButton("Cancel", primary: false) { dismiss() } } } }
}
struct UnitReadingView: View {
    let select: (UnitConversion.Reading) -> Void
    @State private var text = ""
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { VStack(spacing: 10) {
        LiveTextCamera(onText: { text = $0 }, onError: { error = $0 }).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 14))
        Text("Point at a value with a unit. Tap a recognized measurement to convert.").font(.caption).foregroundStyle(.secondary)
        if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.red) }
        List(UnitConversion.readings(text)) { reading in Button(reading.text) { select(reading) } }
    }.padding(12).navigationTitle("Live unit scan").toolbar { TripNavigationButton(title: "Done") { dismiss() } } } }
}
struct UnitPhotoReview: View {
    let readings: [UnitConversion.Reading]
    let text: String
    let select: (UnitConversion.Reading) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { List {
        Section("Choose a measurement") { ForEach(readings) { reading in Button(reading.text) { select(reading) } }
            if readings.isEmpty { Text("No unambiguous unit found. Return to the converter and enter the value with your chosen units.") }
        }
        Section("Recognized text — review for accuracy") { Text(text.isEmpty ? "No text found" : text).textSelection(.enabled) }
    }.navigationTitle("Photo measurements").toolbar { TripNavigationButton(title: "Done") { dismiss() } } } }
}
