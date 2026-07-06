import CoreLocation
import Foundation

final class GeocodingService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func reverseGeocode(
        _ coordinate: CLLocationCoordinate2D,
        languageCode: String
    ) async -> String {
        guard MapsConfig.useGooglePlacesHTTP else {
            return formatCoordinate(coordinate)
        }

        let lang = languageCode == "ar" ? "ar" : "en"
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?latlng=\(coordinate.latitude),\(coordinate.longitude)&language=\(lang)&key=\(MapsConfig.placesWebApiKey)"
        guard let url = URL(string: urlString) else {
            return formatCoordinate(coordinate)
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first else {
                return formatCoordinate(coordinate)
            }
            if let formatted = first["formatted_address"] as? String, !formatted.isEmpty {
                return formatted
            }
        } catch {
            return formatCoordinate(coordinate)
        }
        return formatCoordinate(coordinate)
    }

    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }
}
