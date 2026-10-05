import SwiftUI

struct TripWeatherCard: View {
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
            HStack(alignment: .top, spacing: 12) { column("Home", city: home); column("Destination", city: destination) }
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
                    }.accessibilityLabel("Refresh \(role) weather")
                }
            }
            if let city {
                let place = weather.locations[city.id]
                if let place, let result = weather.cache[place.id] {
                    Label(result.temperatures(result.celsius), systemImage: result.symbol).symbolRenderingMode(.multicolor).font(.subheadline)
                    Text(result.condition).font(.caption)
                    Text("Updated \(result.fetchedAt.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
                    if connection.isOffline { Label("Offline · using saved weather", systemImage: "wifi.slash").font(.caption2).foregroundStyle(.secondary) }
                    else if weather.errors[place.id] != nil { Text("Refresh failed · using saved weather").font(.caption2).foregroundStyle(.secondary) }
                    else if Date().timeIntervalSince(result.fetchedAt) >= 1800 { Text("Saved weather · refresh needed").font(.caption2).foregroundStyle(.secondary) }
                } else if weather.loading.contains(city.id) { ProgressView() }
                else { Text("Weather unavailable").font(.caption) }
            } else { Text("Select your home city above.").font(.caption) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct WeatherCreditView: View {
    @EnvironmentObject private var weather: TripWeatherStore
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if let attribution = weather.attribution {
            Link(destination: attribution.legalPageURL) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    AsyncImage(url: scheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text("Apple Weather").font(.caption2)
                    }
                    .frame(width: 62, height: 12)
                    .alignmentGuide(.firstTextBaseline) { dimensions in dimensions[.bottom] }
                    Text("Sources").font(.caption2).lineLimit(1)
                }
            }
        } else { Text("Apple Weather").font(.caption2).foregroundStyle(.secondary) }
    }
}

private enum WeatherPeriod: String, CaseIterable, Identifiable {
    case hourly = "Hourly", week = "7 days"
    var id: String { rawValue }
}
struct TripWeatherSearchView: View {
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
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Search any city", text: $query).textFieldStyle(.roundedBorder).onSubmit { search() }
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
                if let selected { forecast(selected) }
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
            if selected == nil, let city = home ?? destination {
                await weather.load(city: city)
                if let place = weather.locations[city.id] { selected = place }
                else { message = weather.errors[city.id] ?? "Search for a city to see its weather." }
            }
        }
        .onChange(of: selected?.id) { _, _ in hourPage = 0 }
    }
    private func cityButton(_ city: City) -> some View {
        Button { Task { await weather.load(city: city); if let place = weather.locations[city.id] { choose(place) } else { message = weather.errors[city.id] ?? "Couldn’t find this city." } } } label: {
            Text(city.name).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, minHeight: 36)
        }.buttonStyle(.bordered).tint(selected?.id == weather.locations[city.id]?.id ? .blue : .gray)
    }
    private func forecast(_ place: WeatherLocation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(place.name).font(.title3.weight(.bold)).lineLimit(2)
                Spacer()
                Button { Task { await weather.refresh(place, force: true); message = weather.errors[place.id] ?? "" } } label: {
                    if weather.loading.contains(place.id) { ProgressView().frame(width: 44, height: 44) }
                    else { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }
                }.disabled(weather.loading.contains(place.id)).accessibilityLabel("Refresh weather")
            }
            if let result = weather.cache[place.id] {
                HStack {
                    Image(systemName: result.symbol).symbolRenderingMode(.multicolor).font(.system(size: 32))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.temperatures(result.celsius)).font(.title2.weight(.semibold))
                        Text(result.condition).font(.caption)
                    }
                    Spacer()
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Updated " + result.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                        if connection.isOffline { Label("Offline · using saved forecast", systemImage: "wifi.slash") }
                        else if weather.errors[place.id] != nil { Text("Refresh failed · using saved forecast") }
                        else if Date().timeIntervalSince(result.fetchedAt) >= 1800 { Text("Saved forecast · refresh needed") }
                    }.font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                }
                Picker("Forecast period", selection: $period) { ForEach(WeatherPeriod.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                Text("Forecast times: " + (TimeZone(identifier: result.timeZoneIdentifier ?? "UTC")?.identifier.replacingOccurrences(of: "_", with: " ") ?? "UTC")).font(.caption2).foregroundStyle(.secondary)
                if period == .hourly { hourly(result) } else { weekly(result) }
            } else if weather.loading.contains(place.id) { ProgressView("Loading forecast…") }
            else { Text(connection.isOffline ? "Offline · no saved forecast for this city" : "Forecast unavailable. Try refresh.").font(.subheadline) }
            HStack { Spacer(); WeatherCreditView() }.padding(.top, 2)
        }.tripPanel()
    }
    private func hourly(_ result: CachedWeather) -> some View {
        let hours = result.upcomingHours()
        let pageSize = 4
        let pages = max(1, (hours.count + pageSize - 1) / pageSize)
        return VStack(spacing: 6) {
            ForEach(Array(hours.dropFirst(hourPage * pageSize).prefix(pageSize))) { hour in
                HStack(spacing: 10) {
                    Text(stamp(hour.date, format: "EEE h a", result: result)).font(.subheadline).frame(width: 75, alignment: .leading)
                    Image(systemName: hour.symbol).symbolRenderingMode(.multicolor).frame(width: 30)
                    Text(result.temperatures(hour.celsius)).font(.subheadline).monospacedDigit()
                    Spacer(minLength: 2)
                    Text("\(Int((hour.precipitationChance * 100).rounded()))%").font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel("Chance of precipitation \(Int((hour.precipitationChance * 100).rounded())) percent")
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
                Text("Hourly temperature · precipitation chance").font(.caption2).foregroundStyle(.secondary)
            }
        }.onChange(of: pages) { _, _ in hourPage = min(hourPage, pages - 1) }
    }
    private func weekly(_ result: CachedWeather) -> some View {
        let days = result.upcomingDays()
        return VStack(spacing: 4) {
            ForEach(days) { day in dailyRow(day, result: result) }
            if days.isEmpty { Text("No upcoming daily forecast saved. Refresh when connected.").font(.caption).foregroundStyle(.secondary) }
            else { Text("Daily high / low · precipitation chance").font(.caption2).foregroundStyle(.secondary) }
        }
    }
    private func dailyRow(_ day: CachedWeatherDay, result: CachedWeather) -> some View {
        let chance = Int((day.precipitationChance * 100).rounded())
        let label = [stamp(day.date, format: "EEEE MMMM d", result: result), day.condition,
                     "high " + result.temperatures(day.high), "low " + result.temperatures(day.low),
                     "precipitation chance \(chance) percent"].joined(separator: ", ")
        return HStack(spacing: 8) {
                    Text(stamp(day.date, format: "EEE d", result: result)).font(.caption).frame(width: 55, alignment: .leading)
                    Image(systemName: day.symbol).symbolRenderingMode(.multicolor).frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("H " + result.temperatures(day.high))
                        Text("L " + result.temperatures(day.low)).foregroundStyle(.secondary)
                    }.font(.caption).monospacedDigit()
                    Spacer(minLength: 2)
                    Text("\(Int((day.precipitationChance * 100).rounded()))%").font(.caption).foregroundStyle(.secondary)
                }.frame(minHeight: 38).accessibilityElement(children: .combine)
                    .accessibilityLabel(label)
    }
    private func stamp(_ date: Date, format: String, result: CachedWeather) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: result.timeZoneIdentifier ?? "UTC") ?? .gmt
        formatter.locale = .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    private func choose(_ place: WeatherLocation) {
        selected = place; message = ""; hourPage = 0
        Task { await weather.refresh(place); if selected?.id == place.id { message = weather.errors[place.id] ?? "" } }
    }
    private func search() {
        let requested = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else { return }
        selected = nil; busy = true; message = ""
        Task {
            do { matches = try await weather.search(requested); if matches.isEmpty { message = "No locations found." } }
            catch { message = "Location search needs an internet connection." }
            busy = false
        }
    }
}
