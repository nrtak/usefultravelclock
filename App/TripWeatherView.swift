import SwiftUI

private struct TripWeatherSymbol: View {
    let symbol: String
    var size: CGFloat = 18
    private var snow: Bool { symbol.contains("snow") || symbol.contains("sleet") || symbol.contains("hail") }
    private var tint: Color {
        if snow { return .white }
        if symbol.contains("rain") || symbol.contains("drizzle") || symbol.contains("drop") { return .blue }
        if symbol.contains("bolt") { return .orange }
        if symbol.contains("sun") { return .yellow }
        if symbol.contains("moon") || symbol.contains("star") { return .indigo }
        return .gray
    }
    var body: some View {
        Image(systemName: symbol)
            .symbolRenderingMode(.palette).foregroundStyle(tint, tint.opacity(0.75), tint)
            .font(.system(size: size))
            .padding(snow ? 3 : 0)
            .background { if snow { RoundedRectangle(cornerRadius: 5).fill(Color.blue.opacity(0.65)) } }
            .accessibilityHidden(true)
    }
}

struct TripWeatherCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var weather: TripWeatherStore
    @ObservedObject private var connection = TripConnectionStore.shared
    let home: City?
    let destination: City?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                NavigationLink { TripWeatherSearchView(home: home, destination: destination) } label: {
                    HStack(spacing: 4) {
                        Label("Weather", systemImage: "cloud.sun.fill").symbolRenderingMode(.multicolor).font(.headline)
                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain).accessibilityLabel("More weather")
                Spacer(minLength: 4)
            }
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))) { column("Home", city: home); column("Destination", city: destination) }
            HStack { Spacer(); WeatherCreditView() }.padding(.top, 2)
        }.tripPanel()
        .task(id: home?.id) { if let home { await weather.load(city: home) } }
        .task(id: destination?.id) { if let destination { await weather.load(city: destination) } }
    }
    private func column(_ role: String, city: City?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(city?.name ?? "Choose city").font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if let city {
                    Button { Task { await weather.load(city: city, force: true) } } label: {
                        Image(systemName: "arrow.clockwise").font(.caption).frame(width: 44, height: 44).contentShape(Rectangle())
                    }.disabled(weather.loading.contains(city.id)).accessibilityLabel("Refresh \(role) weather")
                }
            }
            if let city {
                let place = weather.locations[city.id]
                if let place, let result = weather.cache[place.id] {
                    HStack(spacing: 6) { TripWeatherSymbol(symbol: result.symbol); Text(result.temperatures(result.celsius)) }.font(.subheadline)
                    Text(result.condition).font(.caption)
                    TripRefreshStamp(success: weather.lastManualRefresh[place.id], fallback: "Last fetched \(result.fetchedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2)
                    TripVisibleTimeline(interval: 60) { context in
                        Text(weather.status(for: place, now: context.date, offline: connection.isOffline)).font(.caption2).foregroundStyle(.secondary)
                    }
                } else if weather.loading.contains(city.id) { ProgressView() }
                else { Text(connection.isOffline ? "Offline · no saved weather" : "Unavailable · tap refresh").font(.caption).foregroundStyle(.secondary) }
            } else { Text("Select your home city above.").font(.caption) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct WeatherCreditView: View {
    @EnvironmentObject private var weather: TripWeatherStore
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var connection = TripConnectionStore.shared
    private var mark: UIImage? {
        let data = scheme == .dark ? weather.darkMarkData : weather.lightMarkData
        return data.flatMap { UIImage(data: $0) }
    }
    var body: some View {
        Link(destination: weather.credit.legalURL) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { brand; Text("Weather data sources").font(.caption) }
                VStack(alignment: .leading, spacing: 4) { brand; Text("Weather data sources").font(.caption) }
            }.frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel("Apple Weather. Weather data sources")
        .accessibilityHint("Open Apple’s weather attribution and third-party sources")
        .task { await weather.loadAttribution() }
        .onChange(of: connection.isOffline) { _, offline in
            if !offline { Task { await weather.loadAttribution() } }
        }
    }
    @ViewBuilder
    private var brand: some View {
        if let mark {
            Image(uiImage: mark).resizable().scaledToFit().frame(width: 90, height: 20).accessibilityHidden(true)
        } else {
            Text("Apple Weather").font(.caption.weight(.medium)).foregroundStyle(.primary)
        }
    }
}

struct CompactHomeWeather: View {
    @EnvironmentObject private var weather: TripWeatherStore
    @ObservedObject private var connection = TripConnectionStore.shared
    var active = true
    let home: City?
    let destination: City?
    let open: () -> Void
    // A single destination forecast keeps attribution readable without crowding Home.
    private var city: City? { destination ?? home }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Label("Weather", systemImage: "cloud.sun").font(.headline); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                    if let city, let place = weather.locations[city.id], let forecast = weather.cache[place.id] {
                        HStack {
                            Text(city.name).lineLimit(1)
                            TripWeatherSymbol(symbol: forecast.symbol)
                            Text(forecast.temperatures(forecast.celsius)).monospacedDigit().lineLimit(1)
                        }.font(.subheadline)
                        Text("Fetched " + forecast.fetchedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        TripVisibleTimeline(interval: 60, enabled: active) { context in
                            Text(weather.status(for: place, now: context.date, offline: connection.isOffline)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    } else {
                        Text(city == nil ? "Choose a city" : (connection.isOffline ? "No saved forecast" : "Open forecast")).font(.subheadline)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain)
            WeatherCreditView()
        }.task(id: city?.id) { if let city { await weather.load(city: city) } }
    }
}

private enum WeatherPeriod: String, CaseIterable, Identifiable {
    case hourly = "Hourly", week = "7 days"
    var id: String { rawValue }
}
struct TripWeatherSearchView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var weather: TripWeatherStore
    @ObservedObject private var connection = TripConnectionStore.shared
    var home: City? = nil
    var destination: City? = nil
    @State private var query = ""
    @State private var matches: [WeatherLocation] = []
    @State private var selected: WeatherLocation?
    @State private var message = ""
    @State private var busy = false
    @State private var period: WeatherPeriod = .hourly
    @State private var hourPage = 0
    @StateObject private var request = TripRequestScope()
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField(connection.isOffline ? "Search saved locations" : "Search any city", text: $query).textFieldStyle(.roundedBorder).onSubmit { search() }
                    Button { search() } label: { Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }
                        .buttonStyle(.bordered).disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || busy).accessibilityLabel("Search weather locations")
                }
                if home != nil || destination != nil {
                    HStack {
                        if let home { cityButton(home) }
                        if let destination, destination.id != home?.id { cityButton(destination) }
                    }
                }
                if busy { ProgressView("Finding city…") }
                if let selected {
                    TripVisibleTimeline(interval: 60) { context in forecast(selected, now: context.date) }
                }
                else {
                    ForEach(matches) { place in
                        Button { choose(place) } label: {
                            HStack { Text(place.name); Spacer(); Image(systemName: "plus.circle") }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.padding(12)
        }.scrollBounceBehavior(.basedOnSize).navigationTitle("Weather").navigationBarTitleDisplayMode(.inline)
        .task {
            if selected == nil, matches.isEmpty, query.isEmpty, let city = destination ?? home { loadCity(city) }
        }
        .onDisappear { request.cancel(); busy = false }
        .onChange(of: selected?.id) { _, _ in hourPage = 0 }
    }
    private func cityButton(_ city: City) -> some View {
        Button { loadCity(city) } label: {
            Text(city.name).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, minHeight: 36)
        }.buttonStyle(.bordered).tint(selected?.id == weather.locations[city.id]?.id ? .blue : .gray)
    }
    private func forecast(_ place: WeatherLocation, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(place.name).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                Button { Task { await weather.refresh(place, force: true); message = weather.errors[place.id] ?? "" } } label: {
                    if weather.loading.contains(place.id) { ProgressView().frame(width: 44, height: 44) }
                    else { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }
                }.disabled(weather.loading.contains(place.id)).accessibilityLabel("Refresh weather")
            }
            WeatherCreditView()
            if let result = weather.cache[place.id] {
                HStack {
                    TripWeatherSymbol(symbol: result.symbol, size: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.temperatures(result.celsius)).font(.title2.weight(.semibold))
                        Text(result.condition).font(.caption)
                    }
                    Spacer()
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        TripRefreshStamp(success: weather.lastManualRefresh[place.id], fallback: "Last fetched " + result.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                        TripVisibleTimeline(interval: 60) { context in Text(weather.status(for: place, now: context.date, offline: connection.isOffline)) }
                    }.font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                }
                Picker("Forecast period", selection: $period) { ForEach(WeatherPeriod.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                Text(result.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)).map { "Local time · " + $0.identifier.replacingOccurrences(of: "_", with: " ") } ?? "Forecast times shown in UTC").font(.caption2).foregroundStyle(.secondary)
                if period == .hourly { hourly(result, now: now) } else { weekly(result, now: now) }
            } else if weather.loading.contains(place.id) { ProgressView("Loading forecast…") }
            else { Text(connection.isOffline ? "Offline · no saved forecast for this city" : "Forecast unavailable. Try refresh.").font(.subheadline) }
        }.tripPanel()
    }
    private func hourly(_ result: CachedWeather, now: Date) -> some View {
        let hours = result.upcomingHours(now: now)
        let pageSize = 4
        let pages = max(1, (hours.count + pageSize - 1) / pageSize)
        return VStack(spacing: 6) {
            ForEach(Array(hours.dropFirst(hourPage * pageSize).prefix(pageSize))) { hour in
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))) {
                    Text(stamp(hour.date, format: "EEE h a", result: result)).font(.subheadline).frame(minWidth: 75, alignment: .leading)
                    TripWeatherSymbol(symbol: hour.symbol).frame(width: 30)
                    Text(result.temperatures(hour.celsius)).font(.subheadline).monospacedDigit()
                    Spacer(minLength: 2)
                    Text(CachedWeather.precipitationPercent(hour.precipitationChance).map { "\($0)%" } ?? "—").font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel(CachedWeather.precipitationPercent(hour.precipitationChance).map { "Chance of precipitation \($0) percent" } ?? "Chance of precipitation unavailable")
                }.frame(minHeight: 36).accessibilityElement(children: .combine)
            }
            if hours.isEmpty { Text("No upcoming hourly forecast saved. Refresh when connected.").font(.caption).foregroundStyle(.secondary) }
            else {
                HStack {
                    Button("Earlier") { hourPage -= 1 }.disabled(hourPage == 0)
                    Spacer()
                    Text("\(hourPage + 1) / \(pages)").font(.caption)
                    Spacer()
                    Button("Later") { hourPage += 1 }.disabled(hourPage + 1 >= pages)
                }.font(.subheadline).frame(minHeight: 44)
                Text("Rain chance %").font(.caption2).foregroundStyle(.secondary)
            }
        }.onChange(of: pages) { _, _ in hourPage = min(hourPage, pages - 1) }
    }
    private func weekly(_ result: CachedWeather, now: Date) -> some View {
        let days = result.upcomingDays(now: now)
        return VStack(spacing: 2) {
            ForEach(days) { day in dailyRow(day, result: result) }
            if days.isEmpty { Text("No upcoming daily forecast saved. Refresh when connected.").font(.caption).foregroundStyle(.secondary) }
            else { Text("High / low · rain %").font(.caption2).foregroundStyle(.secondary) }
        }
    }
    private func dailyRow(_ day: CachedWeatherDay, result: CachedWeather) -> some View {
        let chance = CachedWeather.precipitationPercent(day.precipitationChance)
        let label = [stamp(day.date, format: "EEEE MMMM d", result: result), day.condition,
                     "high " + result.temperatures(day.high), "low " + result.temperatures(day.low),
                     chance.map { "precipitation chance \($0) percent" } ?? "precipitation chance unavailable"].joined(separator: ", ")
        return (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))) {
                    Text(stamp(day.date, format: "EEE d", result: result)).font(.caption).frame(minWidth: 55, alignment: .leading)
                    TripWeatherSymbol(symbol: day.symbol).frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("H " + result.temperatures(day.high))
                        Text("L " + result.temperatures(day.low)).foregroundStyle(.secondary)
                    }.font(.caption).monospacedDigit()
                    Spacer(minLength: 2)
                    Text(chance.map { "\($0)%" } ?? "—").font(.caption).foregroundStyle(.secondary)
                }.frame(minHeight: 32).accessibilityElement(children: .combine)
                    .accessibilityLabel(label)
    }
    private func stamp(_ date: Date, format: String, result: CachedWeather) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: result.timeZoneIdentifier ?? "UTC") ?? .gmt
        formatter.locale = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    private func loadCity(_ city: City) {
        selected = nil; matches = []; message = ""; busy = true
        request.run { revision in
            await weather.load(city: city)
            guard request.accepts(revision) else { return }
            busy = false
            if let place = weather.locations[city.id] { selected = place }
            else { message = weather.errors[city.id] ?? "Couldn’t find this city." }
        }
    }
    private func choose(_ place: WeatherLocation) {
        selected = place; message = ""; hourPage = 0; busy = false
        request.run { revision in
            await weather.refresh(place)
            guard request.accepts(revision) else { return }
            message = weather.errors[place.id] ?? ""
        }
    }
    private func search() {
        let requested = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else { return }
        selected = nil; matches = []; busy = true; message = ""
        request.run { revision in
            do {
                let found = try await weather.search(requested)
                guard request.accepts(revision) else { return }
                matches = found
                if found.isEmpty { message = connection.isOffline ? "Offline · no saved locations match. Search new cities while connected." : "No locations found." }
            } catch {
                guard request.accepts(revision) else { return }
                message = "Location search needs an internet connection."
            }
            busy = false
        }
    }
}
