//  Useful Travel Clock

// Auto-generated from the web app's city database. Do not edit by hand.

struct City: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String
    var region: String?
    let timeZoneID: String
    var codes: [String]?
    var aliases: [String]?
    var cityState: Bool?

    /// "New York City, NY, USA" — country omitted for city-states.
    var label: String {
        [name, region, cityState == true ? nil : country]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// "New York City, NY" — used on widgets where space is tight.
    var shortLabel: String {
        var parts = [name]
        if let region { parts.append(region) }
        else if cityState != true { parts.append(shortCountry) }
        return parts.joined(separator: ", ")
    }

    /// "UK" style abbreviation for widget labels.
    private var shortCountry: String {
        switch country {
        case "United Kingdom": return "UK"
        case "United Arab Emirates": return "UAE"
        default: return country
        }
    }
}

extension City {
    /// "America/Los Angeles" + airport codes, e.g. "America/Los Angeles · LAX BUR LGB".
    var subtitle: String {
        let zone = timeZoneID.replacingOccurrences(of: "_", with: " ")
        if let codes, !codes.isEmpty {
            return zone + " · " + codes.joined(separator: " ")
        }
        return zone
    }
}

let cities: [City] = [
    City(id: "nyc", name: "New York City", country: "USA", region: "NY", timeZoneID: "America/New_York", codes: ["JFK", "LGA", "EWR", "NYC"]),
    City(id: "lon", name: "London", country: "United Kingdom", timeZoneID: "Europe/London", codes: ["LHR", "LGW", "LCY", "STN", "LON"]),
    City(id: "mil", name: "Milan", country: "Italy", timeZoneID: "Europe/Rome", codes: ["MXP", "LIN", "BGY", "MIL"]),
    City(id: "tyo", name: "Tokyo", country: "Japan", timeZoneID: "Asia/Tokyo", codes: ["HND", "NRT", "TYO"]),
    City(id: "mel", name: "Melbourne", country: "Australia", timeZoneID: "Australia/Melbourne", codes: ["MEL"]),
    City(id: "sfo", name: "San Francisco", country: "USA", region: "CA", timeZoneID: "America/Los_Angeles", codes: ["SFO", "OAK", "SJC"]),
    City(id: "dxb", name: "Dubai", country: "UAE", timeZoneID: "Asia/Dubai", codes: ["DXB", "DWC"]),
    City(id: "sin", name: "Singapore", country: "Singapore", timeZoneID: "Asia/Singapore", codes: ["SIN"], cityState: true),
    City(id: "ber", name: "Berlin", country: "Germany", timeZoneID: "Europe/Berlin", codes: ["BER"]),
    City(id: "syd", name: "Sydney", country: "Australia", timeZoneID: "Australia/Sydney", codes: ["SYD"]),
    City(id: "lax", name: "Los Angeles", country: "USA", region: "CA", timeZoneID: "America/Los_Angeles", codes: ["LAX", "BUR", "LGB"]),
    City(id: "par", name: "Paris", country: "France", timeZoneID: "Europe/Paris", codes: ["CDG", "ORY", "PAR"]),
    City(id: "hkg", name: "Hong Kong", country: "China", timeZoneID: "Asia/Hong_Kong", codes: ["HKG"], cityState: true),
    City(id: "bom", name: "Mumbai", country: "India", timeZoneID: "Asia/Kolkata", codes: ["BOM"], aliases: ["Bombay"]),
    City(id: "sao", name: "São Paulo", country: "Brazil", timeZoneID: "America/Sao_Paulo", codes: ["GRU", "CGH", "SAO"], aliases: ["Sao Paulo"]),
    City(id: "tor", name: "Toronto", country: "Canada", timeZoneID: "America/Toronto", codes: ["YYZ", "YTZ"]),
    City(id: "ams", name: "Amsterdam", country: "Netherlands", timeZoneID: "Europe/Amsterdam", codes: ["AMS"]),
    City(id: "sel", name: "Seoul", country: "South Korea", timeZoneID: "Asia/Seoul", codes: ["ICN", "GMP", "SEL"]),
    City(id: "chi", name: "Chicago", country: "USA", region: "IL", timeZoneID: "America/Chicago", codes: ["ORD", "MDW", "CHI"]),
    City(id: "dfw", name: "Dallas", country: "USA", region: "TX", timeZoneID: "America/Chicago", codes: ["DFW", "DAL"]),
    City(id: "hou", name: "Houston", country: "USA", region: "TX", timeZoneID: "America/Chicago", codes: ["IAH", "HOU"]),
    City(id: "atl", name: "Atlanta", country: "USA", region: "GA", timeZoneID: "America/New_York", codes: ["ATL"]),
    City(id: "mia", name: "Miami", country: "USA", region: "FL", timeZoneID: "America/New_York", codes: ["MIA", "FLL"]),
    City(id: "bos", name: "Boston", country: "USA", region: "MA", timeZoneID: "America/New_York", codes: ["BOS"]),
    City(id: "was", name: "Washington", country: "USA", region: "DC", timeZoneID: "America/New_York", codes: ["DCA", "IAD", "WAS"]),
    City(id: "sea", name: "Seattle", country: "USA", region: "WA", timeZoneID: "America/Los_Angeles", codes: ["SEA"]),
    City(id: "den", name: "Denver", country: "USA", region: "CO", timeZoneID: "America/Denver", codes: ["DEN"]),
    City(id: "phx", name: "Phoenix", country: "USA", region: "AZ", timeZoneID: "America/Phoenix", codes: ["PHX"]),
    City(id: "las", name: "Las Vegas", country: "USA", region: "NV", timeZoneID: "America/Los_Angeles", codes: ["LAS"]),
    City(id: "msp", name: "Minneapolis", country: "USA", region: "MN", timeZoneID: "America/Chicago", codes: ["MSP"]),
    City(id: "hnl", name: "Honolulu", country: "USA", region: "HI", timeZoneID: "Pacific/Honolulu", codes: ["HNL"]),
    City(id: "anc", name: "Anchorage", country: "USA", region: "AK", timeZoneID: "America/Anchorage", codes: ["ANC"]),
    City(id: "aus", name: "Austin", country: "USA", region: "TX", timeZoneID: "America/Chicago", codes: ["AUS"]),
    City(id: "phl", name: "Philadelphia", country: "USA", region: "PA", timeZoneID: "America/New_York", codes: ["PHL"]),
    City(id: "san", name: "San Diego", country: "USA", region: "CA", timeZoneID: "America/Los_Angeles", codes: ["SAN"]),
    City(id: "det", name: "Detroit", country: "USA", region: "MI", timeZoneID: "America/Detroit", codes: ["DTW"]),
    City(id: "yvr", name: "Vancouver", country: "Canada", timeZoneID: "America/Vancouver", codes: ["YVR"]),
    City(id: "yul", name: "Montréal", country: "Canada", timeZoneID: "America/Toronto", codes: ["YUL"], aliases: ["Montreal"]),
    City(id: "yyc", name: "Calgary", country: "Canada", timeZoneID: "America/Edmonton", codes: ["YYC"]),
    City(id: "mex", name: "Mexico City", country: "Mexico", timeZoneID: "America/Mexico_City", codes: ["MEX"]),
    City(id: "bog", name: "Bogotá", country: "Colombia", timeZoneID: "America/Bogota", codes: ["BOG"], aliases: ["Bogota"]),
    City(id: "lim", name: "Lima", country: "Peru", timeZoneID: "America/Lima", codes: ["LIM"]),
    City(id: "scl", name: "Santiago", country: "Chile", timeZoneID: "America/Santiago", codes: ["SCL"]),
    City(id: "bue", name: "Buenos Aires", country: "Argentina", timeZoneID: "America/Argentina/Buenos_Aires", codes: ["EZE", "AEP", "BUE"]),
    City(id: "rio", name: "Rio de Janeiro", country: "Brazil", timeZoneID: "America/Sao_Paulo", codes: ["GIG", "SDU", "RIO"]),
    City(id: "pty", name: "Panama City", country: "Panama", timeZoneID: "America/Panama", codes: ["PTY"]),
    City(id: "dub", name: "Dublin", country: "Ireland", timeZoneID: "Europe/Dublin", codes: ["DUB"]),
    City(id: "lis", name: "Lisbon", country: "Portugal", timeZoneID: "Europe/Lisbon", codes: ["LIS"]),
    City(id: "mad", name: "Madrid", country: "Spain", timeZoneID: "Europe/Madrid", codes: ["MAD"]),
    City(id: "bcn", name: "Barcelona", country: "Spain", timeZoneID: "Europe/Madrid", codes: ["BCN"]),
    City(id: "rom", name: "Rome", country: "Italy", timeZoneID: "Europe/Rome", codes: ["FCO", "CIA", "ROM"]),
    City(id: "zrh", name: "Zurich", country: "Switzerland", timeZoneID: "Europe/Zurich", codes: ["ZRH"]),
    City(id: "gva", name: "Geneva", country: "Switzerland", timeZoneID: "Europe/Zurich", codes: ["GVA"]),
    City(id: "muc", name: "Munich", country: "Germany", timeZoneID: "Europe/Berlin", codes: ["MUC"]),
    City(id: "fra", name: "Frankfurt", country: "Germany", timeZoneID: "Europe/Berlin", codes: ["FRA"]),
    City(id: "bru", name: "Brussels", country: "Belgium", timeZoneID: "Europe/Brussels", codes: ["BRU"]),
    City(id: "cph", name: "Copenhagen", country: "Denmark", timeZoneID: "Europe/Copenhagen", codes: ["CPH"]),
    City(id: "osl", name: "Oslo", country: "Norway", timeZoneID: "Europe/Oslo", codes: ["OSL"]),
    City(id: "sto", name: "Stockholm", country: "Sweden", timeZoneID: "Europe/Stockholm", codes: ["ARN", "STO"]),
    City(id: "hel", name: "Helsinki", country: "Finland", timeZoneID: "Europe/Helsinki", codes: ["HEL"]),
    City(id: "vie", name: "Vienna", country: "Austria", timeZoneID: "Europe/Vienna", codes: ["VIE"]),
    City(id: "prg", name: "Prague", country: "Czechia", timeZoneID: "Europe/Prague", codes: ["PRG"]),
    City(id: "waw", name: "Warsaw", country: "Poland", timeZoneID: "Europe/Warsaw", codes: ["WAW"]),
    City(id: "bud", name: "Budapest", country: "Hungary", timeZoneID: "Europe/Budapest", codes: ["BUD"]),
    City(id: "ath", name: "Athens", country: "Greece", timeZoneID: "Europe/Athens", codes: ["ATH"]),
    City(id: "ist", name: "Istanbul", country: "Turkey", timeZoneID: "Europe/Istanbul", codes: ["IST", "SAW"]),
    City(id: "mow", name: "Moscow", country: "Russia", timeZoneID: "Europe/Moscow", codes: ["SVO", "DME", "MOW"]),
    City(id: "kbp", name: "Kyiv", country: "Ukraine", timeZoneID: "Europe/Kyiv", codes: ["KBP"], aliases: ["Kiev"]),
    City(id: "edi", name: "Edinburgh", country: "United Kingdom", timeZoneID: "Europe/London", codes: ["EDI"]),
    City(id: "rek", name: "Reykjavík", country: "Iceland", timeZoneID: "Atlantic/Reykjavik", codes: ["KEF"], aliases: ["Reykjavik"]),
    City(id: "cai", name: "Cairo", country: "Egypt", timeZoneID: "Africa/Cairo", codes: ["CAI"]),
    City(id: "los", name: "Lagos", country: "Nigeria", timeZoneID: "Africa/Lagos", codes: ["LOS"]),
    City(id: "nbo", name: "Nairobi", country: "Kenya", timeZoneID: "Africa/Nairobi", codes: ["NBO"]),
    City(id: "jnb", name: "Johannesburg", country: "South Africa", timeZoneID: "Africa/Johannesburg", codes: ["JNB"]),
    City(id: "cpt", name: "Cape Town", country: "South Africa", timeZoneID: "Africa/Johannesburg", codes: ["CPT"]),
    City(id: "cmn", name: "Casablanca", country: "Morocco", timeZoneID: "Africa/Casablanca", codes: ["CMN"]),
    City(id: "add", name: "Addis Ababa", country: "Ethiopia", timeZoneID: "Africa/Addis_Ababa", codes: ["ADD"]),
    City(id: "tlv", name: "Tel Aviv", country: "Israel", timeZoneID: "Asia/Jerusalem", codes: ["TLV"]),
    City(id: "doh", name: "Doha", country: "Qatar", timeZoneID: "Asia/Qatar", codes: ["DOH"]),
    City(id: "ruh", name: "Riyadh", country: "Saudi Arabia", timeZoneID: "Asia/Riyadh", codes: ["RUH"]),
    City(id: "auh", name: "Abu Dhabi", country: "UAE", timeZoneID: "Asia/Dubai", codes: ["AUH"]),
    City(id: "khi", name: "Karachi", country: "Pakistan", timeZoneID: "Asia/Karachi", codes: ["KHI"]),
    City(id: "del", name: "Delhi", country: "India", timeZoneID: "Asia/Kolkata", codes: ["DEL"], aliases: ["New Delhi"]),
    City(id: "blr", name: "Bengaluru", country: "India", timeZoneID: "Asia/Kolkata", codes: ["BLR"], aliases: ["Bangalore"]),
    City(id: "maa", name: "Chennai", country: "India", timeZoneID: "Asia/Kolkata", codes: ["MAA"], aliases: ["Madras"]),
    City(id: "ccu", name: "Kolkata", country: "India", timeZoneID: "Asia/Kolkata", codes: ["CCU"], aliases: ["Calcutta"]),
    City(id: "cmb", name: "Colombo", country: "Sri Lanka", timeZoneID: "Asia/Colombo", codes: ["CMB"]),
    City(id: "ktm", name: "Kathmandu", country: "Nepal", timeZoneID: "Asia/Kathmandu", codes: ["KTM"]),
    City(id: "dac", name: "Dhaka", country: "Bangladesh", timeZoneID: "Asia/Dhaka", codes: ["DAC"]),
    City(id: "bkk", name: "Bangkok", country: "Thailand", timeZoneID: "Asia/Bangkok", codes: ["BKK", "DMK"]),
    City(id: "han", name: "Hanoi", country: "Vietnam", timeZoneID: "Asia/Ho_Chi_Minh", codes: ["HAN"]),
    City(id: "sgn", name: "Ho Chi Minh City", country: "Vietnam", timeZoneID: "Asia/Ho_Chi_Minh", codes: ["SGN"], aliases: ["Saigon"]),
    City(id: "kul", name: "Kuala Lumpur", country: "Malaysia", timeZoneID: "Asia/Kuala_Lumpur", codes: ["KUL"]),
    City(id: "cgk", name: "Jakarta", country: "Indonesia", timeZoneID: "Asia/Jakarta", codes: ["CGK"]),
    City(id: "dps", name: "Bali", country: "Indonesia", timeZoneID: "Asia/Makassar", codes: ["DPS"], aliases: ["Denpasar"]),
    City(id: "mnl", name: "Manila", country: "Philippines", timeZoneID: "Asia/Manila", codes: ["MNL"]),
    City(id: "tpe", name: "Taipei", country: "Taiwan", timeZoneID: "Asia/Taipei", codes: ["TPE"]),
    City(id: "pek", name: "Beijing", country: "China", timeZoneID: "Asia/Shanghai", codes: ["PEK", "PKX"]),
    City(id: "sha", name: "Shanghai", country: "China", timeZoneID: "Asia/Shanghai", codes: ["PVG", "SHA"]),
    City(id: "can", name: "Shenzhen", country: "China", timeZoneID: "Asia/Shanghai", codes: ["SZX"]),
    City(id: "osa", name: "Osaka", country: "Japan", timeZoneID: "Asia/Tokyo", codes: ["KIX", "ITM", "OSA"]),
    City(id: "alm", name: "Almaty", country: "Kazakhstan", timeZoneID: "Asia/Almaty", codes: ["ALA"]),
    City(id: "bne", name: "Brisbane", country: "Australia", timeZoneID: "Australia/Brisbane", codes: ["BNE"]),
    City(id: "per", name: "Perth", country: "Australia", timeZoneID: "Australia/Perth", codes: ["PER"]),
    City(id: "adl", name: "Adelaide", country: "Australia", timeZoneID: "Australia/Adelaide", codes: ["ADL"]),
    City(id: "akl", name: "Auckland", country: "New Zealand", timeZoneID: "Pacific/Auckland", codes: ["AKL"]),
    City(id: "wlg", name: "Wellington", country: "New Zealand", timeZoneID: "Pacific/Auckland", codes: ["WLG"]),
    City(id: "nan", name: "Nadi", country: "Fiji", timeZoneID: "Pacific/Fiji", codes: ["NAN"]),
    City(id: "hnl2", name: "Papeete", country: "French Polynesia", timeZoneID: "Pacific/Tahiti", codes: ["PPT"], aliases: ["Tahiti"]),
]

let defaultCityIDs: [String] = ["nyc", "lon", "mil", "tyo", "mel"]

let popularCityIDs: [String] = ["nyc", "lax", "sfo", "chi", "lon", "par", "ber", "ams", "dxb", "sin", "tyo", "hkg", "sel", "syd", "mel", "tor", "sao", "bom"]

let clockCityDatabase = cities
