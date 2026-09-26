// SPDX-License-Identifier: GPL-3.0-only
// See NOTICE.md for copyright and license notices.

//  Useful Travel Clock

import SwiftUI

/// Time converter: pick two cities, convert a specific wall-clock time,
/// matching the web app's Converter tab.
struct ConverterView: View {
    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.colorScheme) private var scheme

    @State private var fromCityID: String = defaultCityIDs.first ?? "nyc"
    @State private var toCityID: String = defaultCityIDs.dropFirst().first ?? "nyc"
    @State private var day: String = ""
    @State private var time: String = "12:00"
    @State private var result: Date?
    @State private var conversionError: String?
    @State private var useLaterOccurrence = false
    @State private var pickingField: Field?

    enum Field { case from, to }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                inputs
                if isRepeatedTime {
                    Picker("This time occurs twice", selection: $useLaterOccurrence) {
                        Text("First occurrence").tag(false)
                        Text("Second occurrence").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Text("The clocks move back on this date. Choose which occurrence to convert.")
                        .font(.caption)
                        .foregroundStyle(Design.mutedForeground(scheme))
                }
                buttons
                if let conversionError {
                    Text(conversionError)
                        .font(.callout)
                        .accessibilityLabel("Conversion unavailable. \(conversionError)")
                }
                if result != nil { resultCard }
            }
            .padding(16)
        }
        .onAppear(perform: syncNow)
        .onChange(of: day) { _ in convert() }
        .onChange(of: time) { _ in convert() }
        .onChange(of: fromCityID) { _ in convert() }
        .onChange(of: toCityID) { _ in convert() }
        .onChange(of: useLaterOccurrence) { _ in convert() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundStyle(Color(red: 0.29, green: 0.55, blue: 0.78))
            VStack(alignment: .leading, spacing: 1) {
                Text("Time converter").font(.system(size: 16, weight: .bold))
                Text("Convert a time between two cities")
                    .font(.system(size: 11))
                    .foregroundStyle(Design.mutedForeground(scheme))
            }
        }
    }

    private var inputs: some View {
        VStack(spacing: 10) {
            fieldRow(label: "From", cityID: fromCityID) { pickingField = .from }
            HStack(spacing: 10) {
                dateField
                timeField
            }
            fieldRow(label: "To", cityID: toCityID) { pickingField = .to }
        }
    }

    private func fieldRow(label: String, cityID: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.mutedForeground(scheme))
            Button(action: action) {
                HStack {
                    Text(CitySearch.city(withID: cityID, in: store.allCities)?.label ?? "Select a city")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Design.foreground(scheme))
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 11)).foregroundStyle(Design.mutedForeground(scheme))
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Design.secondary(scheme).opacity(0.45)))
            }
        }
        .sheet(item: $pickingField) { field in
            CityPickerSheet(initialID: field == .from ? fromCityID : toCityID) { picked in
                if field == .from { fromCityID = picked } else { toCityID = picked }
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.mutedForeground(scheme))
            DatePicker("Date in the selected source city", selection: dateBinding, displayedComponents: .date)
                .environment(\.timeZone, pickerCalendar.timeZone)
                .environment(\.calendar, pickerCalendar)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Design.secondary(scheme).opacity(0.45)))
        }
    }

    private var timeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TIME")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Design.mutedForeground(scheme))
            DatePicker("Time in the selected source city", selection: timeBinding, displayedComponents: .hourAndMinute)
                .environment(\.timeZone, pickerCalendar.timeZone)
                .environment(\.calendar, pickerCalendar)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Design.secondary(scheme).opacity(0.45)))
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button(action: convert) {
                Text("Convert time")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Design.primary(scheme)))
                    .foregroundStyle(Design.background(scheme))
            }
            Button(action: syncNow) {
                Text("Now")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Design.secondary(scheme)))
                    .foregroundStyle(Design.foreground(scheme))
            }
        }
    }

    private var resultCard: some View {
        Group {
            if let at = result,
               let from = CitySearch.city(withID: fromCityID, in: store.allCities),
               let to = CitySearch.city(withID: toCityID, in: store.allCities) {
                let fromTime = TimeEngine.zonedTime(at, timeZoneID: from.timeZoneID)
                let toTime = TimeEngine.zonedTime(at, timeZoneID: to.timeZoneID)
                HStack(alignment: .center, spacing: 12) {
                    resultColumn(city: from, time: fromTime, alignTrailing: false)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13))
                        .foregroundStyle(Design.mutedForeground(scheme))
                    resultColumn(city: to, time: toTime, alignTrailing: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Design.cityRow(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Design.border(scheme).opacity(0.7)))
                )
            }
        }
    }

    private func resultColumn(city: City, time: ZonedTime, alignTrailing: Bool) -> some View {
        VStack(alignment: alignTrailing ? .trailing : .leading, spacing: 2) {
            Text(city.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(time.hm).font(.system(size: 20, weight: .bold).monospacedDigit())
                Text(time.period).font(.system(size: 14, weight: .semibold))
            }
            Text(time.date)
                .font(.system(size: 11))
                .foregroundStyle(Design.mutedForeground(scheme))
        }
        .foregroundStyle(Design.foreground(scheme))
        .frame(maxWidth: .infinity)
    }

    // MARK: Logic

    // Pickers transport wall-clock components in UTC. Applying the source zone
    // happens only during conversion, so the device zone cannot shift the input
    // and skipped/repeated times remain selectable for explicit validation.
    private var pickerCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { TimeEngine.fromZonedInput(day: day, time: "12:00", timeZoneID: "UTC") ?? Date() },
            set: { day = TimeEngine.toZonedInput($0, timeZoneID: "UTC").day }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { TimeEngine.fromZonedInput(day: "2026-01-01", time: time.isEmpty ? "12:00" : time, timeZoneID: "UTC") ?? Date() },
            set: { time = TimeEngine.toZonedInput($0, timeZoneID: "UTC").time }
        )
    }

    private var fromZoneID: String {
        CitySearch.city(withID: fromCityID, in: store.allCities)?.timeZoneID ?? "UTC"
    }

    private func syncNow() {
        let now = Date()
        let values = TimeEngine.toZonedInput(now, timeZoneID: fromZoneID)
        day = values.day
        time = values.time
        let first = TimeEngine.fromZonedInput(day: day, time: time, timeZoneID: fromZoneID)
        useLaterOccurrence = first.map { now.timeIntervalSince($0) >= 60 } ?? false
        convert()
    }

    private var isRepeatedTime: Bool {
        guard let first = TimeEngine.fromZonedInput(day: day, time: time, timeZoneID: fromZoneID),
              let last = TimeEngine.fromZonedInput(day: day, time: time, timeZoneID: fromZoneID,
                                                  repeatedTimePolicy: .last) else { return false }
        return first != last
    }

    private func convert() {
        result = TimeEngine.fromZonedInput(day: day, time: time, timeZoneID: fromZoneID,
                                          repeatedTimePolicy: useLaterOccurrence ? .last : .first)
        conversionError = result == nil
            ? "This local date or time does not exist in the selected city. A clock change may skip it. Choose another time."
            : nil
    }
}

extension ConverterView.Field: Identifiable {
    var id: Int { hashValue }
}

/// Searchable city picker sheet, used by both converter fields.
struct CityPickerSheet: View {
    let initialID: String
    let onPick: (String) -> Void

    @EnvironmentObject private var store: UsefulTravelClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { city in
                    Button {
                        onPick(city.id)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city.label).font(.system(size: 15, weight: .medium))
                                Text(TimeEngine.readableZone(city.timeZoneID))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if city.id == initialID { Image(systemName: "checkmark").foregroundStyle(.tint) }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Type any city, country or code")
            .navigationTitle("Select a city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Cancel") { dismiss() } }
        }
        .presentationDetents([.medium, .large])
    }

    private var results: [City] {
        query.trimmingCharacters(in: .whitespaces).isEmpty
            ? CitySearch.popularCities(in: store.allCities)
            : Array(CitySearch.search(query, in: store.allCities).prefix(12))
    }
}
