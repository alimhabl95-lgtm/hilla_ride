import Foundation

enum MapsConfig {
    /// iOS map-rendering key — Firebase "iOS key" in project `hello-tiktok-57dc5`.
    /// Restrict to iOS apps + bundle `com.hillaride.hillaRide`.
    /// APIs: Maps SDK for iOS (required).
    static let mapRenderKey = "AIzaSyDD4PxDlgfhdKj-_Z7sCkWHZ0hrVRtD2aA"

    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !key.isEmpty, key != "YOUR_GOOGLE_MAPS_API_KEY" {
            return key
        }
        return mapRenderKey
    }

    /// Firebase "Browser key" in `hello-tiktok-57dc5` — HTTP Places / Geocoding / web maps.
    /// Application restrictions must be None (or HTTP referrers), NOT iOS/Android apps.
    /// APIs must include: Places API (New), Maps JavaScript API (for web).
    static let placesWebApiKey = "AIzaSyAsgktwgQMXi9i5majam_z3Yion1_0qqLY"

    static var isConfigured: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }

    static var useGooglePlacesHTTP: Bool {
        !placesWebApiKey.isEmpty && placesWebApiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }
}
