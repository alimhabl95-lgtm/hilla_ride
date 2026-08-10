import CoreLocation
import Foundation
import os.log

/// Multi-source place search aligned with Flutter `GeocodingService.searchPlacesInRegion`:
/// local catalog + Google Places (New) + Nominatim fallback.
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
        languageCode: String,
        regionLabel: String?,
        subDistrictId: String
    ) async -> [PlacesSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let minLength = containsArabic(trimmed) ? 1 : 2
        guard trimmed.count >= minLength else {
            lastStatusMessage = nil
            return []
        }

        async let localTask = LocalPlacesCatalog.shared.search(
            query: trimmed,
            preferArabic: languageCode.lowercased().hasPrefix("ar")
        )
        async let googleTask = google.searchPlaces(
            query: trimmed,
            center: center,
            radiusKm: radiusKm,
            languageCode: languageCode,
            regionLabel: regionLabel
        )
        async let nominatimTask = nominatimSearch(
            query: trimmed,
            center: center,
            radiusKm: radiusKm,
            languageCode: languageCode
        )

        let local = await localTask
        let googleResults = await googleTask
        let nominatim = await nominatimTask

        let softRadius = max(radiusKm * 1.35, radiusKm + 8)
        var merged = merge(
            groups: [local, googleResults, nominatim],
            center: center,
            maxDistanceKm: softRadius
        )

        // If the tight radius wiped everything (common when Google biases to Hilla
        // while the selected sub-district center is farther east), keep the nearest
        // district-scoped hits instead of showing an empty list.
        if merged.isEmpty {
            merged = merge(
                groups: [local, googleResults, nominatim],
                center: center,
                maxDistanceKm: max(45, softRadius)
            )
        }

        if merged.isEmpty {
            switch google.lastError {
            case .apiDenied:
                lastStatusMessage = "apiDenied"
            case .httpStatus, .network:
                lastStatusMessage = "network"
            default:
                lastStatusMessage = "no_results"
            }
            log.warning(
                "Place search empty q=\(trimmed, privacy: .public) google=\(googleResults.count) local=\(local.count) nominatim=\(nominatim.count) err=\(self.google.lastError?.debugDescription ?? "none", privacy: .public)"
            )
        } else {
            lastStatusMessage = nil
            log.info("Place search ok q=\(trimmed, privacy: .public) count=\(merged.count)")
        }

        _ = subDistrictId // retained for API parity; geo-scoping uses center + softRadius
        return Array(merged.prefix(25))
    }

    private func merge(
        groups: [[PlacesSearchResult]],
        center: CLLocationCoordinate2D,
        maxDistanceKm: Double
    ) -> [PlacesSearchResult] {
        var seen = Set<String>()
        var scored: [(PlacesSearchResult, Double)] = []

        for group in groups {
            for place in group {
                let distance = GeoMath.distanceKm(from: center, to: place.coordinate)
                guard distance <= maxDistanceKm else { continue }
                let key = String(format: "%.4f,%.4f", place.latitude, place.longitude)
                guard seen.insert(key).inserted else { continue }
                scored.append((place, distance))
            }
        }

        scored.sort { $0.1 < $1.1 }
        return scored.map(\.0)
    }

    private func nominatimSearch(
        query: String,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        languageCode: String
    ) async -> [PlacesSearchResult] {
        let delta = max(0.05, radiusKm / 111.0)
        let left = center.longitude - delta
        let right = center.longitude + delta
        let top = center.latitude + delta
        let bottom = center.latitude - delta
        let lang = languageCode.lowercased().hasPrefix("ar") ? "ar" : "en"

        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(query) Iraq"),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: "15"),
            URLQueryItem(name: "countrycodes", value: "iq"),
            URLQueryItem(name: "accept-language", value: lang),
            URLQueryItem(name: "viewbox", value: "\(left),\(top),\(right),\(bottom)"),
            URLQueryItem(name: "bounded", value: "1")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("HelloTukTuk/1.0 (place-search)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

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

    private func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0600...0x06FF).contains(scalar.value)
        }
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
