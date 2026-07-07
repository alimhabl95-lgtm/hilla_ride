import Foundation

enum MapsConfig {
    /// iOS map-rendering key (auto-created by Firebase) in the `hello-tiktok-57dc5`
    /// project — the same project where "Maps SDK for iOS" is enabled. It is
    /// restricted to the iOS app bundle, which is required for tiles to render on
    /// iOS. Must NOT be the Android map key or the HTTP Places key.
    static let mapRenderKey = "AIzaSyDD4PxDlgfhdKj-_Z7sCkWHZ0hrVRtD2aA"

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
