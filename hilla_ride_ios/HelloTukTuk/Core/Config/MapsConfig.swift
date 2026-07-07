import Foundation

enum MapsConfig {
    /// Key 1 — the map-rendering key used by the Google Maps SDK (matches the
    /// Android map widget and the Flutter iOS `Runner/Info.plist`). This must NOT
    /// be the HTTP Places key, otherwise map tiles come back blank on iOS.
    static let mapRenderKey = "AIzaSyBke5bjy0cHxAnYJ8x89WlvjECLOTcAbGE"

    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !key.isEmpty, key != "YOUR_GOOGLE_MAPS_API_KEY" {
            return key
        }
        return mapRenderKey
    }

    /// Key 2 — HTTP Places/Geocoding key (same as Flutter `placesWebApiKeyEmbedded`).
    static let placesWebApiKey = "AIzaSyCygbeGlDUlA7l0GkJjB8TUHvHNUlHwsBg"

    static var isConfigured: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }

    static var useGooglePlacesHTTP: Bool {
        !placesWebApiKey.isEmpty && placesWebApiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }
}
