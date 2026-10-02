import SwiftUI

struct TripWeatherCard: View {
    @EnvironmentObject private var weather: TripWeatherStore
    let home: City?
    let destination: City?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Label("Weather", systemImage: "cloud.sun.fill").symbolRenderingMode(.multicolor); Spacer(); NavigationLink("More") { TripWeatherSearchView() } }
            HStack(alignment: .top, spacing: 12) { column("Home", city: home); column("Destination", city: destination) }
            HStack { Spacer(); WeatherCreditView() }
        }.tripPanel()
        .task(id: home?.id) { if let home { await weather.load(city: home) } }
        .task(id: destination?.id) { if let destination { await weather.load(city: destination) } }
    }
    private func column(_ role: String, city: City?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(role).font(.caption)
            HStack(spacing: 4) {
                Text(city?.name ?? "Choose city").font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if let city {
                    Button { Task { await weather.load(city: city, force: true) } } label: {
                        Image(systemName: "arrow.clockwise").font(.caption).frame(width: 32, height: 32)
                    }.accessibilityLabel("Refresh \(role) weather")
                }
            }
            if let city {
                let place = weather.locations[city.id]
                if let place, let result = weather.cache[place.id] {
                    Label(result.temperatures(result.celsius), systemImage: result.symbol).symbolRenderingMode(.multicolor).font(.subheadline)
                    Text(result.condition).font(.caption)
                    Text("Updated \(result.fetchedAt.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundStyle(.secondary)
                    if weather.errors[place.id] != nil || Date().timeIntervalSince(result.fetchedAt) >= 1800 { Text("Cached forecast").font(.caption2).foregroundStyle(.secondary) }
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
                HStack(spacing: 6) { AsyncImage(url: scheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in image.resizable().scaledToFit() } placeholder: { Text("Apple Weather").font(.caption2) }.frame(width: 62, height: 10); Text("Data sources").font(.system(size: 10)) }
            }
        } else { Text("Source: Apple Weather · WeatherKit").font(.caption2).foregroundStyle(.secondary) }
    }
}
struct TripWeatherSearchView: View {
    @EnvironmentObject private var weather: TripWeatherStore
    @State private var query = ""
    @State private var matches: [WeatherLocation] = []
    @State private var selected: WeatherLocation?
    @State private var message = ""
    @State private var busy = false
    var body: some View {
        VStack(spacing: 12) {
            HStack { TextField("Search any city", text: $query).textFieldStyle(.roundedBorder).onSubmit { search() }; Button("Search") { search() }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || busy) }
            if busy { ProgressView() }
            if let selected {
                Text(selected.name).font(.title2)
                if let result = weather.cache[selected.id] {
                    Image(systemName: result.symbol).symbolRenderingMode(.multicolor).font(.system(size: 44))
                    Text(result.temperatures(result.celsius)).font(.title)
                    Text(result.condition)
                    if let high = result.high, let low = result.low { Text("H \(result.temperatures(high)) · L \(result.temperatures(low))").font(.caption) }
                    Text("Last updated: \(result.fetchedAt.formatted())").font(.caption2)
                    if weather.errors[selected.id] != nil { Text("Cached forecast — refresh failed").font(.caption) }
                }
                Button("Refresh") { Task { await weather.refresh(selected, force: true); message = weather.errors[selected.id] ?? "" } }
                WeatherCreditView()
            } else {
                ForEach(matches) { place in Button(place.name) { selected = place; Task { await weather.refresh(place); message = weather.errors[place.id] ?? "" } }.frame(maxWidth: .infinity, alignment: .leading).padding(8) }
            }
            Text(message).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding().navigationTitle("Weather").navigationBarTitleDisplayMode(.inline)
    }
    private func search() {
        selected = nil; busy = true; message = ""
        Task { do { matches = try await weather.search(query); if matches.isEmpty { message = "No locations found." } } catch { message = "Location search needs an internet connection." }; busy = false }
    }
}
