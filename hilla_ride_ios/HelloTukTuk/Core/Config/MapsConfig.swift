import Foundation

enum MapsConfig {
    static var apiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
           !key.isEmpty {
            return key
        }
        return ""
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty && apiKey != "YOUR_GOOGLE_MAPS_API_KEY"
    }
}
