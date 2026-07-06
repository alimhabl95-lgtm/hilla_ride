import Foundation

enum MapsConfig {
    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !key.isEmpty {
            return key
        }
        return ""
    }

    /// HTTP Places key (same as Flutter `placesWebApiKeyEmbedded`).
    static let placesWebApiKey = "AIzaSyCygbeGlDUlA7l0GkJjB8TUHvHNUlHwsBg"

    static var isConfigured: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }

    static var useGooglePlacesHTTP: Bool {
        !placesWebApiKey.isEmpty && placesWebApiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }
}
