import CoreLocation
import Foundation

struct PlacesSearchResult: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var asMapPlace: MapPlace {
        MapPlace(label: label, coordinate: coordinate)
    }
}

final class GooglePlacesService {
    private let session: URLSession
    private var apiDenied = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchPlaces(
        query: String,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        languageCode: String,
        regionLabel: String? = nil
    ) async -> [PlacesSearchResult] {
        guard MapsConfig.useGooglePlacesHTTP, !apiDenied, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = regionLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let enriched = label.isEmpty
            ? "\(trimmedQuery) Babil Iraq"
            : "\(trimmedQuery) \(label) Babil Iraq"

        // Restrict (not just bias) results to a rectangle around the selected
        // area so places from other cities never appear in the list.
        let latDelta = radiusKm / 111.0
        let lngDelta = radiusKm / (111.0 * max(0.1, cos(center.latitude * .pi / 180)))
        let body: [String: Any] = [
            "textQuery": enriched,
            "languageCode": languageCode,
            "regionCode": "iq",
            "maxResultCount": 20,
            "locationRestriction": [
                "rectangle": [
                    "low": [
                        "latitude": center.latitude - latDelta,
                        "longitude": center.longitude - lngDelta
                    ],
                    "high": [
                        "latitude": center.latitude + latDelta,
                        "longitude": center.longitude + lngDelta
                    ]
                ]
            ]
        ]

        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(MapsConfig.placesWebApiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "places.displayName,places.formattedAddress,places.location",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        request.timeoutInterval = 10

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if (response as? HTTPURLResponse)?.statusCode == 403 { apiDenied = true }
                return []
            }
            return parsePlaces(data)
        } catch {
            return []
        }
    }

    private func parsePlaces(_ data: Data) -> [PlacesSearchResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let places = json["places"] as? [[String: Any]] else {
            return []
        }

        return places.compactMap { place in
            guard let location = place["location"] as? [String: Any],
                  let lat = (location["latitude"] as? NSNumber)?.doubleValue,
                  let lng = (location["longitude"] as? NSNumber)?.doubleValue else {
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
                label = String(format: "%.4f, %.4f", lat, lng)
            }
            return PlacesSearchResult(label: label, latitude: lat, longitude: lng)
        }
    }
}
