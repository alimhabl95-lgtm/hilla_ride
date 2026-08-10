import CoreLocation
import FirebaseFunctions
import Foundation
import os.log

/// Fetches road polylines via the same `getDrivingRoute` Cloud Function Flutter uses,
/// with optional direct Google fallbacks.
final class DirectionsRouteService {
    private let session: URLSession
    private let functions = Functions.functions(region: "us-central1")
    private let log = Logger(subsystem: "com.hillaride.hillaRide", category: "Directions")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func routePath(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D] {
        if let cloud = await cloudFunctionRoute(from: origin, to: destination), !cloud.isEmpty {
            return cloud
        }
        if let routes = await computeRoutes(from: origin, to: destination), !routes.isEmpty {
            return routes
        }
        if let legacy = await legacyDirections(from: origin, to: destination), !legacy.isEmpty {
            return legacy
        }
        return [origin, destination]
    }

    private func cloudFunctionRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D]? {
        do {
            let result = try await functions.httpsCallable("getDrivingRoute").call([
                "originLat": origin.latitude,
                "originLng": origin.longitude,
                "destLat": destination.latitude,
                "destLng": destination.longitude
            ])
            guard let data = result.data as? [String: Any],
                  let encoded = data["encodedPolyline"] as? String,
                  !encoded.isEmpty else {
                return nil
            }
            return Self.decodePolyline(encoded)
        } catch {
            log.error("getDrivingRoute CF failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func computeRoutes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D]? {
        guard MapsConfig.useGooglePlacesHTTP,
              let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes") else {
            return nil
        }

        let body: [String: Any] = [
            "origin": [
                "location": [
                    "latLng": [
                        "latitude": origin.latitude,
                        "longitude": origin.longitude
                    ]
                ]
            ],
            "destination": [
                "location": [
                    "latLng": [
                        "latitude": destination.latitude,
                        "longitude": destination.longitude
                    ]
                ]
            ],
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
            "computeAlternativeRoutes": false,
            "languageCode": "ar-IQ",
            "units": "METRIC"
        ]

        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(MapsConfig.placesWebApiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("routes.polyline.encodedPolyline", forHTTPHeaderField: "X-Goog-FieldMask")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let polyline = routes.first?["polyline"] as? [String: Any],
                  let encoded = polyline["encodedPolyline"] as? String else {
                return nil
            }
            return Self.decodePolyline(encoded)
        } catch {
            return nil
        }
    }

    private func legacyDirections(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D]? {
        guard MapsConfig.useGooglePlacesHTTP else { return nil }
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")
        components?.queryItems = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "region", value: "iq"),
            URLQueryItem(name: "key", value: MapsConfig.placesWebApiKey)
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["status"] as? String) == "OK",
                  let routes = json["routes"] as? [[String: Any]],
                  let overview = routes.first?["overview_polyline"] as? [String: Any],
                  let encoded = overview["points"] as? String else {
                return nil
            }
            return Self.decodePolyline(encoded)
        } catch {
            return nil
        }
    }

    static func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            var shift = 0
            var result = 0
            var byte: Int
            repeat {
                byte = Int(encoded[index].asciiValue ?? 63) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1f) << shift
                shift += 5
            } while byte >= 0x20 && index < encoded.endIndex
            let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += deltaLat

            shift = 0
            result = 0
            repeat {
                byte = Int(encoded[index].asciiValue ?? 63) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1f) << shift
                shift += 5
            } while byte >= 0x20 && index < encoded.endIndex
            let deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += deltaLng

            points.append(
                CLLocationCoordinate2D(
                    latitude: Double(lat) / 1e5,
                    longitude: Double(lng) / 1e5
                )
            )
        }
        return points
    }
}
