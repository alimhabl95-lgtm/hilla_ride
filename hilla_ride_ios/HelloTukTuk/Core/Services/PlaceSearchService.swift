import CoreLocation
import Foundation
import os.log

/// Multi-source place search aligned with Flutter `GeocodingService.searchPlacesInRegion`:
/// local catalog + Google Places + Photon + Overpass + Nominatim, then strict sub-district validation.
final class PlaceSearchService {
    private let google = GooglePlacesService()
    private let session: URLSession
    private let log = Logger(subsystem: "com.hillaride.hillaRide", category: "PlaceSearch")

    private(set) var lastStatusMessage: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(
        query: String,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        biasRadiusKm: Double,
        languageCode: String,
        regionLabel: String?,
        subDistrictId: String,
        districtName: String? = nil,
        subDistrictName: String? = nil,
        boundary: [CLLocationCoordinate2D]? = nil
    ) async -> [PlacesSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let minLength = containsArabic(trimmed) ? 1 : 2
        guard trimmed.count >= minLength else {
            lastStatusMessage = nil
            return []
        }
        guard !subDistrictId.isEmpty else {
            lastStatusMessage = "no_results_in_area"
            return []
        }

        let sub = await MainActor.run { BabilRegions.subDistrict(byId: subDistrictId) }
        let filterRadiusKm = max(1.0, radiusKm)
        let providerBiasKm = max(filterRadiusKm, biasRadiusKm)
        let biasBbox = GeoPolygon.boundingBox(
            center: center,
            radiusKm: providerBiasKm,
            storedBoundary: boundary
        )

        async let localTask = localPlacesMatching(
            query: trimmed,
            subDistrictId: subDistrictId,
            languageCode: languageCode
        )
        async let googleTask = google.searchPlaces(
            query: trimmed,
            center: center,
            radiusKm: providerBiasKm,
            languageCode: languageCode,
            regionLabel: regionLabel
        )

        let local = await localTask
        var googleResults = await googleTask

        var merged = await mergeInSubDistrict(
            subDistrictId: subDistrictId,
            center: center,
            groups: [local, googleResults]
        )

        if merged.count >= 3 {
            lastStatusMessage = nil
            log.info(
                "Place search fast path q=\(trimmed, privacy: .public) sub=\(subDistrictId, privacy: .public) count=\(merged.count)"
            )
            return Array(merged.prefix(25))
        }

        if merged.isEmpty, googleResults.isEmpty {
            googleResults = await google.searchPlaces(
                query: trimmed,
                center: center,
                radiusKm: providerBiasKm + 4.0,
                languageCode: languageCode,
                regionLabel: nil
            )
            merged = await mergeInSubDistrict(
                subDistrictId: subDistrictId,
                center: center,
                groups: [local, googleResults]
            )
        }

        if merged.isEmpty, !googleResults.isEmpty {
            merged = await mergeWithinServiceArea(
                center: sub.center,
                radiusKm: sub.searchRadiusKm,
                storedBoundary: sub.boundary,
                searchCenter: center,
                groups: [googleResults]
            )
        }

        if merged.count >= 3 {
            lastStatusMessage = nil
            return Array(merged.prefix(25))
        }

        let supplemental = await supplementalSearchResults(
            query: trimmed,
            center: center,
            biasRadiusKm: providerBiasKm,
            biasBbox: biasBbox,
            languageCode: languageCode,
            regionLabel: regionLabel,
            subDistrictName: subDistrictName
        )

        merged = await mergeInSubDistrict(
            subDistrictId: subDistrictId,
            center: center,
            groups: [local, googleResults, supplemental.photon, supplemental.overpass, supplemental.nominatim]
        )

        if merged.isEmpty {
            let categoryResults = await overpassCategorySearch(query: trimmed, bbox: biasBbox)
            merged = await mergeInSubDistrict(
                subDistrictId: subDistrictId,
                center: center,
                groups: [categoryResults]
            )
        }

        if merged.isEmpty, !googleResults.isEmpty {
            merged = await mergeWithinServiceArea(
                center: sub.center,
                radiusKm: sub.searchRadiusKm,
                storedBoundary: sub.boundary,
                searchCenter: center,
                groups: [googleResults, supplemental.photon, supplemental.nominatim]
            )
        }

        let rawCount = local.count + googleResults.count
            + supplemental.photon.count + supplemental.overpass.count + supplemental.nominatim.count

        if merged.isEmpty {
            switch google.lastError {
            case .apiDenied where rawCount == 0:
                lastStatusMessage = "apiDenied"
            case .network, .httpStatus where rawCount == 0:
                lastStatusMessage = "network"
            default:
                lastStatusMessage = "no_results_in_area"
            }
            log.warning(
                "Place search empty q=\(trimmed, privacy: .public) sub=\(subDistrictId, privacy: .public) raw=\(rawCount) google=\(googleResults.count) local=\(local.count) nominatim=\(supplemental.nominatim.count) overpass=\(supplemental.overpass.count) err=\(self.google.lastError?.debugDescription ?? "none", privacy: .public)"
            )
        } else {
            lastStatusMessage = nil
            log.info(
                "Place search ok q=\(trimmed, privacy: .public) sub=\(subDistrictId, privacy: .public) count=\(merged.count)"
            )
        }

        return Array(merged.prefix(25))
    }

    private struct SupplementalSearchResults {
        let photon: [PlacesSearchResult]
        let overpass: [PlacesSearchResult]
        let nominatim: [PlacesSearchResult]
    }

    /// OSM/Photon providers are slow — cap total wait so Google-first results aren't blocked.
    private func supplementalSearchResults(
        query: String,
        center: CLLocationCoordinate2D,
        biasRadiusKm: Double,
        biasBbox: GeoBoundingBox,
        languageCode: String,
        regionLabel: String?,
        subDistrictName: String?
    ) async -> SupplementalSearchResults {
        await withTaskGroup(of: (Int, [PlacesSearchResult]).self) { group in
            group.addTask {
                let results = await self.photonSearch(
                    query: query,
                    center: center,
                    radiusKm: biasRadiusKm,
                    languageCode: languageCode
                )
                return (0, results)
            }
            group.addTask {
                let results = await self.overpassSearch(query: query, bbox: biasBbox)
                return (1, results)
            }
            group.addTask {
                let results = await self.nominatimSearch(
                    query: query,
                    bbox: biasBbox,
                    languageCode: languageCode,
                    subDistrictName: subDistrictName,
                    regionLabel: regionLabel
                )
                return (2, results)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                return (-1, [])
            }

            var photon: [PlacesSearchResult] = []
            var overpass: [PlacesSearchResult] = []
            var nominatim: [PlacesSearchResult] = []
            var finished = 0

            for await (kind, results) in group {
                if kind == -1 { break }
                switch kind {
                case 0: photon = results
                case 1: overpass = results
                case 2: nominatim = results
                default: break
                }
                finished += 1
                if finished == 3 { break }
            }
            group.cancelAll()
            return SupplementalSearchResults(photon: photon, overpass: overpass, nominatim: nominatim)
        }
    }

    // MARK: - Region merge

    private func mergeInSubDistrict(
        subDistrictId: String,
        center: CLLocationCoordinate2D,
        groups: [[PlacesSearchResult]]
    ) async -> [PlacesSearchResult] {
        await MainActor.run {
            var seen = Set<String>()
            var scored: [(PlacesSearchResult, Double)] = []

            for group in groups {
                for place in group {
                    guard BabilRegions.isWithin(subDistrictId: subDistrictId, point: place.coordinate) else {
                        continue
                    }
                    let key = String(format: "%.4f,%.4f", place.latitude, place.longitude)
                    guard seen.insert(key).inserted else { continue }
                    let distance = GeoMath.distanceKm(from: center, to: place.coordinate)
                    scored.append((place, distance))
                }
            }

            scored.sort { $0.1 < $1.1 }
            return scored.map(\.0)
        }
    }

    /// Relaxed merge for provider results that Google/OSM returned inside the
    /// service-area circle/polygon but were rejected by overlapping sub-district logic.
    private func mergeWithinServiceArea(
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        storedBoundary: [CLLocationCoordinate2D]?,
        searchCenter: CLLocationCoordinate2D,
        groups: [[PlacesSearchResult]]
    ) async -> [PlacesSearchResult] {
        await MainActor.run {
            var seen = Set<String>()
            var scored: [(PlacesSearchResult, Double)] = []

            for group in groups {
                for place in group {
                    guard GeoPolygon.isWithinBoundary(
                        point: place.coordinate,
                        center: center,
                        radiusKm: radiusKm,
                        storedBoundary: storedBoundary
                    ) else {
                        continue
                    }
                    let key = String(format: "%.4f,%.4f", place.latitude, place.longitude)
                    guard seen.insert(key).inserted else { continue }
                    let distance = GeoMath.distanceKm(from: searchCenter, to: place.coordinate)
                    scored.append((place, distance))
                }
            }

            scored.sort { $0.1 < $1.1 }
            return scored.map(\.0)
        }
    }

    private func localPlacesMatching(
        query: String,
        subDistrictId: String,
        languageCode: String
    ) async -> [PlacesSearchResult] {
        let preferArabic = languageCode.lowercased().hasPrefix("ar")
        let matches = await LocalPlacesCatalog.shared.search(query: query, preferArabic: preferArabic)
        return await MainActor.run {
            matches.filter { BabilRegions.isWithin(subDistrictId: subDistrictId, point: $0.coordinate) }
        }
    }

    // MARK: - Nominatim

    private func nominatimSearch(
        query: String,
        bbox: GeoBoundingBox,
        languageCode: String,
        subDistrictName: String?,
        regionLabel: String?
    ) async -> [PlacesSearchResult] {
        let usesArabic = languageCode.lowercased().hasPrefix("ar") || containsArabic(query)
        let subDistrict = subDistrictName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let label = regionLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let searchQuery: String
        if subDistrict.isEmpty && label.isEmpty {
            searchQuery = usesArabic ? "\(query), بابل, العراق" : "\(query), Babil, Iraq"
        } else {
            let area = subDistrict.isEmpty ? label : subDistrict
            searchQuery = usesArabic
                ? "\(query), \(area), بابل, العراق"
                : "\(query), \(area), Babil, Iraq"
        }

        let lang = usesArabic ? "ar,en" : "en,ar"

        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "15"),
            URLQueryItem(name: "countrycodes", value: "iq"),
            URLQueryItem(name: "addressdetails", value: "1"),
            URLQueryItem(
                name: "viewbox",
                value: "\(bbox.west),\(bbox.north),\(bbox.east),\(bbox.south)"
            ),
            URLQueryItem(name: "bounded", value: "0")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("HelloTukTuk/1.0 (com.hillaride.hilla_ride)", forHTTPHeaderField: "User-Agent")
        request.setValue(lang, forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 7

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return rows.compactMap { row in
                guard let lat = GooglePlacesService.doubleValue(row["lat"]),
                      let lon = GooglePlacesService.doubleValue(row["lon"]) else {
                    return nil
                }
                let name = (row["display_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (row["name"] as? String)
                    ?? String(format: "%.4f, %.4f", lat, lon)
                return PlacesSearchResult(label: name, latitude: lat, longitude: lon)
            }
        } catch {
            log.error("Nominatim failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Photon

    private func photonSearch(
        query: String,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        languageCode: String
    ) async -> [PlacesSearchResult] {
        var components = URLComponents(string: "https://photon.komoot.io/api/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "lat", value: String(center.latitude)),
            URLQueryItem(name: "lon", value: String(center.longitude)),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "lang", value: languageCode.lowercased().hasPrefix("ar") ? "ar" : "en")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 7

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]] else {
                return []
            }

            return features.compactMap { feature in
                guard let geometry = feature["geometry"] as? [String: Any],
                      let coords = geometry["coordinates"] as? [Any],
                      coords.count >= 2,
                      let lon = GooglePlacesService.doubleValue(coords[0]),
                      let lat = GooglePlacesService.doubleValue(coords[1]) else {
                    return nil
                }
                let props = feature["properties"] as? [String: Any] ?? [:]
                let name = (props["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? query
                let city = (props["city"] as? String) ?? (props["county"] as? String) ?? ""
                let street = (props["street"] as? String) ?? ""
                let parts = [name, street, city].filter { !$0.isEmpty }
                let label = parts.joined(separator: ", ")
                let distance = GeoMath.distanceKm(from: center, to: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                guard distance <= radiusKm else { return nil }
                return PlacesSearchResult(label: label, latitude: lat, longitude: lon)
            }
        } catch {
            return []
        }
    }

    // MARK: - Overpass

    private func overpassSearch(
        query: String,
        bbox: GeoBoundingBox
    ) async -> [PlacesSearchResult] {
        let escaped = query.replacingOccurrences(of: "\"", with: "\\\"")
        let south = bbox.south
        let north = bbox.north
        let west = bbox.west
        let east = bbox.east
        let wordPattern = overpassWordPattern(query)
        let categoryLines = overpassCategoryLines(
            south: south, west: west, north: north, east: east, query: query
        )

        var body = """
        [out:json][timeout:7];
        (
          nwr["name"~"\(escaped)",i](\(south),\(west),\(north),\(east));
          nwr["name:ar"~"\(escaped)",i](\(south),\(west),\(north),\(east));
        """
        if !wordPattern.isEmpty {
            body += """

              nwr["name"~"\(wordPattern)",i](\(south),\(west),\(north),\(east));
              nwr["name:ar"~"\(wordPattern)",i](\(south),\(west),\(north),\(east));
            """
        }
        if !categoryLines.isEmpty {
            body += "\n" + categoryLines.joined(separator: "\n")
        }
        body += """

        );
        out center 30;
        """
        return await runOverpassQuery(body)
    }

    private func overpassCategorySearch(
        query: String,
        bbox: GeoBoundingBox
    ) async -> [PlacesSearchResult] {
        let south = bbox.south
        let north = bbox.north
        let west = bbox.west
        let east = bbox.east
        let lines = overpassCategoryLines(
            south: south, west: west, north: north, east: east, query: query
        )
        guard !lines.isEmpty else { return [] }

        let body = """
        [out:json][timeout:7];
        (
        \(lines.joined(separator: "\n"))
        );
        out center 40;
        """
        return await runOverpassQuery(body)
    }

    private func runOverpassQuery(_ overpass: String) async -> [PlacesSearchResult] {
        let endpoints = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter"
        ]

        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = formBody(name: "data", value: overpass)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 7

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let elements = json["elements"] as? [[String: Any]] else {
                    continue
                }

                return elements.compactMap { element in
                    let tags = element["tags"] as? [String: Any] ?? [:]
                    let lat = GooglePlacesService.doubleValue(element["lat"])
                        ?? GooglePlacesService.doubleValue((element["center"] as? [String: Any])?["lat"])
                    let lon = GooglePlacesService.doubleValue(element["lon"])
                        ?? GooglePlacesService.doubleValue((element["center"] as? [String: Any])?["lon"])
                    guard let lat, let lon else { return nil }
                    return PlacesSearchResult(
                        label: osmPlaceLabel(tags: tags),
                        latitude: lat,
                        longitude: lon
                    )
                }
            } catch {
                continue
            }
        }
        return []
    }

    private func overpassWordPattern(_ query: String) -> String {
        let words = query
            .split { $0.isWhitespace || $0 == "," || $0 == "،" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
            .map { $0.replacingOccurrences(of: "\"", with: "") }
        guard !words.isEmpty else { return "" }
        if words.count == 1 { return words[0] }
        return words.joined(separator: "|")
    }

    private func overpassCategoryLines(
        south: Double,
        west: Double,
        north: Double,
        east: Double,
        query: String
    ) -> [String] {
        let q = normalizeArabicQuery(query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        var lines: [String] = []
        let bbox = "(\(south),\(west),\(north),\(east))"

        func add(_ line: String) {
            if !lines.contains(line) { lines.append("  \(line)") }
        }

        func matches(_ needles: [String]) -> Bool {
            needles.contains { q.contains(normalizeArabicQuery($0)) }
        }

        if matches(["سوبر", "ماركت", "supermarket", "grocery", "بقال", "هايبر", "market"]) {
            add("nwr[\"shop\"~\"supermarket|convenience|general|grocery|department_store|mall\"]\(bbox);")
        }
        if matches(["سيار", "معرض", "car", "dealer", "vehicle", "motors", "بيع"]) {
            add("nwr[\"shop\"~\"car|car_repair|trade|tyres|motorcycle\"]\(bbox);")
            add("nwr[\"amenity\"=\"car_dealer\"]\(bbox);")
        }
        if matches(["مطعم", "restaurant", "food", "كاف", "cafe", "وجبات"]) {
            add("nwr[\"amenity\"~\"restaurant|cafe|fast_food|food_court\"]\(bbox);")
        }
        if matches(["صيدل", "pharmacy", "drug", "دواء"]) {
            add("nwr[\"amenity\"=\"pharmacy\"]\(bbox);")
            add("nwr[\"shop\"=\"chemist\"]\(bbox);")
        }
        if matches(["بنك", "bank", "atm", "صراف"]) {
            add("nwr[\"amenity\"~\"bank|atm\"]\(bbox);")
        }
        if matches(["مدرس", "school", "روض"]) {
            add("nwr[\"amenity\"~\"school|kindergarten\"]\(bbox);")
        }
        if matches(["جامع", "university", "college", "كلية"]) {
            add("nwr[\"amenity\"~\"university|college\"]\(bbox);")
        }
        if matches(["محطة", "وقود", "fuel", "gas", "petrol", "بنزين"]) {
            add("nwr[\"amenity\"=\"fuel\"]\(bbox);")
        }
        if matches(["مسجد", "mosque", "جامع"]) {
            add("nwr[\"amenity\"=\"place_of_worship\"][\"religion\"=\"muslim\"]\(bbox);")
        }
        if matches(["مستشف", "hospital", "clinic", "عياد", "طب"]) {
            add("nwr[\"amenity\"~\"hospital|clinic|doctors\"]\(bbox);")
        }
        if matches(["سوق", "shop", "store", "محل", "تجار"]) {
            add("nwr[\"shop\"]\(bbox);")
            add("nwr[\"amenity\"=\"marketplace\"]\(bbox);")
        }

        return lines
    }

    private func osmPlaceLabel(tags: [String: Any]) -> String {
        if let nameAr = tags["name:ar"] as? String, !nameAr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let name = tags["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let shop = tags["shop"] as? String {
            return osmTagLabelAr(shop)
        }
        if let amenity = tags["amenity"] as? String {
            return osmTagLabelAr(amenity)
        }
        return "مكان"
    }

    private func osmTagLabelAr(_ tag: String) -> String {
        let labels: [String: String] = [
            "supermarket": "سوبرماركت",
            "convenience": "بقالة",
            "general": "محل",
            "grocery": "بقالة",
            "mall": "مجمع تجاري",
            "department_store": "متجر",
            "car": "معرض سيارات",
            "car_repair": "ورشة سيارات",
            "car_dealer": "معرض سيارات",
            "trade": "معرض",
            "restaurant": "مطعم",
            "cafe": "مقهى",
            "fast_food": "وجبات سريعة",
            "pharmacy": "صيدلية",
            "chemist": "صيدلية",
            "bank": "بنك",
            "atm": "صراف آلي",
            "fuel": "محطة وقود",
            "hospital": "مستشفى",
            "clinic": "عيادة",
            "school": "مدرسة",
            "university": "جامعة",
            "college": "كلية",
            "place_of_worship": "مسجد",
            "marketplace": "سوق"
        ]
        return labels[tag] ?? tag
    }

    // MARK: - Helpers

    private func normalizeArabicQuery(_ value: String) -> String {
        value
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ة", with: "ه")
    }

    private func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value)
        }
    }

    private func formBody(name: String, value: String) -> Data? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        func encode(_ string: String) -> String {
            string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
        }
        return "\(encode(name))=\(encode(value))".data(using: .utf8)
    }
}

// MARK: - Local catalog

private struct LocalPlaceRecord: Decodable {
    let nameEn: String
    let nameAr: String
    let keywords: [String]
    let lat: Double
    let lon: Double
}

final class LocalPlacesCatalog {
    static let shared = LocalPlacesCatalog()

    private var places: [LocalPlaceRecord]?
    private let lock = NSLock()

    func search(query: String, preferArabic: Bool) async -> [PlacesSearchResult] {
        let all = load()
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }

        return all.compactMap { place in
            let haystack = normalize(
                [place.nameAr, place.nameEn].joined(separator: " ") + " " + place.keywords.joined(separator: " ")
            )
            guard haystack.contains(normalizedQuery)
                    || place.keywords.contains(where: { normalize($0).contains(normalizedQuery) }) else {
                return nil
            }
            return PlacesSearchResult(
                label: preferArabic ? place.nameAr : place.nameEn,
                latitude: place.lat,
                longitude: place.lon
            )
        }
    }

    private func load() -> [LocalPlaceRecord] {
        lock.lock()
        defer { lock.unlock() }
        if let places { return places }

        let urls: [URL?] = [
            Bundle.main.url(forResource: "hilla_places", withExtension: "json"),
            Bundle.main.url(forResource: "hilla_places", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([LocalPlaceRecord].self, from: data) {
                places = decoded
                return decoded
            }
        }

        places = Self.embeddedFallback
        return places ?? []
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ة", with: "ه")
            .replacingOccurrences(of: "ى", with: "ي")
    }

    /// Minimal embedded fallback so search still works if the JSON resource is missing.
    private static let embeddedFallback: [LocalPlaceRecord] = [
        LocalPlaceRecord(
            nameEn: "Al Hashimiyah General Hospital",
            nameAr: "مستشفى الهاشمية العام",
            keywords: ["hospital", "مستشفى", "هاشمية", "hashimiya"],
            lat: 32.3630848,
            lon: 44.6490908
        ),
        LocalPlaceRecord(
            nameEn: "Hashimiya Center",
            nameAr: "مركز الهاشمية",
            keywords: ["hashimiya", "center", "هاشمية", "مركز"],
            lat: 32.374,
            lon: 44.665
        ),
        LocalPlaceRecord(
            nameEn: "Al-Qasim",
            nameAr: "القاسم",
            keywords: ["qasim", "قاسم"],
            lat: 32.3014,
            lon: 44.6892
        ),
        LocalPlaceRecord(
            nameEn: "Hilla City Center",
            nameAr: "مركز مدينة الحلة",
            keywords: ["hilla", "center", "حلة", "مركز"],
            lat: 32.4637,
            lon: 44.4197
        ),
        LocalPlaceRecord(
            nameEn: "Hilla General Teaching Hospital",
            nameAr: "مستشفى الحلة التعليمي العام",
            keywords: ["hospital", "مستشفى", "حلة", "hilla"],
            lat: 32.460605,
            lon: 44.42289
        )
    ]
}
