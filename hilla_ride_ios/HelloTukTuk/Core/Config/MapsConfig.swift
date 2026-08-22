import Foundation

enum MapsConfig {
    /// iOS map-rendering key — Firebase "iOS key" in project `hello-tiktok-57dc5`.
    /// Restrict to iOS apps + bundle `com.hillaride.hillaRide`.
    /// APIs: Maps SDK for iOS (required).
    /// Do NOT put this Maps-only key in GoogleService-Info.plist — Auth needs
    /// Identity Toolkit (see Browser key below).
    static let mapRenderKey = "AIzaSyDD4PxDlgfhdKj-_Z7sCkWHZ0hrVRtD2aA"

    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !key.isEmpty, key != "YOUR_GOOGLE_MAPS_API_KEY" {
            return key
        }
        return mapRenderKey
    }

    /// Firebase "Browser key" — HTTP Places / Firebase Auth / web maps.
    /// Used by GoogleService-Info.plist API_KEY (login) and Places HTTP.
    /// Application restrictions must be None (or HTTP referrers only), NOT iOS/Android.
    /// APIs must include: Identity Toolkit, Places API (New), Maps JavaScript API.
    static let placesWebApiKey = "AIzaSyAsgktwgQMXi9i5majam_z3Yion1_0qqLY"

    static var isConfigured: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }

    static var useGooglePlacesHTTP: Bool {
        !placesWebApiKey.isEmpty && placesWebApiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }
}
