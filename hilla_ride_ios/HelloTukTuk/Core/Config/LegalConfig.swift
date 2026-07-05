import Foundation

enum LegalConfig {
    private static let host = "https://hello-tiktok-57dc5.web.app"

    static func privacyPolicyURL(languageCode: String = "en") -> URL {
        let lang = languageCode == "ar" ? "ar" : "en"
        return URL(string: "\(host)/legal/privacy.html?lang=\(lang)")!
    }

    static func termsOfServiceURL(languageCode: String = "en") -> URL {
        let lang = languageCode == "ar" ? "ar" : "en"
        return URL(string: "\(host)/legal/terms.html?lang=\(lang)")!
    }
}
