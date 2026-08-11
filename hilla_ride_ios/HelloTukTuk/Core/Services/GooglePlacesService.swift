import CoreLocation
import Foundation
import os.log

struct PlacesSearchResult: Identifiable, Equatable {
    let label: String
    let latitude: Double
    let longitude: Double

    var id: String {
        "\(latitude),\(longitude)|\(label)"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var asMapPlace: MapPlace {
        MapPlace(label: label, coordinate: coordinate)
    }
}

enum PlacesSearchError: Equatable {
    case disabled
    case emptyQuery
    case httpStatus(Int)
    case network(String)
    case decode
    case apiDenied

    var debugDescription: String {
        switch self {
        case .disabled: return "Places HTTP disabled"
        case .emptyQuery: return "Empty query"
        case .httpStatus(let code): return "HTTP \(code)"
        case .network(let message): return "Network: \(message)"
        case .decode: return "Decode failed"
        case .apiDenied: return "API denied (403)"
        }
    }
}

/// Google Places API (New) text search over HTTP — aligned with Flutter `GooglePlacesService`.
final class GooglePlacesService {
    private let session: URLSession
    private let log = Logger(subsystem: "com.hillaride.hillaRide", category: "GooglePlaces")

    private(set) var lastError: PlacesSearchError?
    private(set) var apiDenied = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchPlaces(
        query: String,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        languageCode: String,
        regionLabel: String? = nil,
        districtName: String? = nil,
        subDistrictName: String? = nil
    ) async -> [PlacesSearchResult] {
        lastError = nil

        guard MapsConfig.useGooglePlacesHTTP else {
            lastError = .disabled
            return []
        }
        if apiDenied {
            lastError = .apiDenied
            return []
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            lastError = .emptyQuery
            return []
        }

        let label = regionLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let district = districtName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subDistrict = subDistrictName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var queryParts = [trimmedQuery]
        if !subDistrict.isEmpty {
            queryParts.append(subDistrict)
        } else if !label.isEmpty {
            queryParts.append(label)
        }
        if !district.isEmpty {
            queryParts.append(district)
        }
        queryParts.append("Babil Iraq")
        let enriched = queryParts.joined(separator: " ")

        let lang = normalizedLanguageCode(languageCode)
        // Tight bias to the selected city area; sub-district polygon filtering happens after merge.
        let biasRadiusMeters = max(800.0, min(radiusKm * 1_000.0, 18_000.0))
        let body: [String: Any] = [
            "textQuery": enriched,
            "languageCode": lang,
            "regionCode": "iq",
            "maxResultCount": 20,
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": center.latitude,
                        "longitude": center.longitude
                    ],
                    "radius": biasRadiusMeters
                ]
            ]
        ]

        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            lastError = .decode
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(MapsConfig.placesWebApiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "places.displayName,places.formattedAddress,places.location",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        request.timeoutInterval = 12

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                lastError = .network("No HTTP response")
                return []
            }
            guard (200...299).contains(http.statusCode) else {
                if http.statusCode == 403 {
                    apiDenied = true
                    lastError = .apiDenied
                } else {
                    lastError = .httpStatus(http.statusCode)
                }
                let snippet = String(data: data, encoding: .utf8)?.prefix(240) ?? ""
                log.error("Places search failed status=\(http.statusCode) body=\(snippet, privacy: .public)")
                return []
            }
            let places = parsePlaces(data)
            log.info("Places search q=\(enriched, privacy: .public) count=\(places.count)")
            return places
        } catch {
            lastError = .network(error.localizedDescription)
            log.error("Places search network error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func normalizedLanguageCode(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.hasPrefix("ar") { return "ar" }
        if lower.hasPrefix("en") { return "en" }
        return "ar"
    }

    private func parsePlaces(_ data: Data) -> [PlacesSearchResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            lastError = .decode
            return []
        }
        guard let places = json["places"] as? [[String: Any]] else {
            // Empty `{}` is a valid "no results" response.
            return []
        }

        return places.compactMap { place in
            guard let location = place["location"] as? [String: Any],
                  let lat = Self.doubleValue(location["latitude"]),
                  let lng = Self.doubleValue(location["longitude"]) else {
                return nil
            }
            let displayName = (place["displayName"] as? [String: Any])?["text"] as? String ?? ""
            let address = place["formattedAddress"] as? String ?? ""
            let label: String
            if !displayName.isEmpty && !address.isEmpty {
                label = "\(displayName), \(address)"
            } else if !displayName.isEmpty {
                label = displayName
            } else if !address.isEmpty {
                label = address
            } else {
                label = String(format: "%.5f, %.5f", lat, lng)
            }
            return PlacesSearchResult(label: label, latitude: lat, longitude: lng)
        }
    }

    /// JSONSerialization may yield NSNumber or Double depending on platform bridging.
    static func doubleValue(_ any: Any?) -> Double? {
        if let number = any as? NSNumber {
            return number.doubleValue
        }
        if let value = any as? Double {
            return value
        }
        if let value = any as? Float {
            return Double(value)
        }
        if let value = any as? Int {
            return Double(value)
        }
        if let value = any as? String {
            return Double(value)
        }
        return nil
    }
}
