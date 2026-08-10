import Foundation

struct AppRemoteConfig: Equatable {
    var maintenanceMode = false
    var maintenanceMessageEn = ""
    var maintenanceMessageAr = ""
    var minAndroidBuild = 0
    var minIosBuild = 0
    var forceUpdateMessageEn = ""
    var forceUpdateMessageAr = ""
    var androidStoreUrl = ""
    var iosStoreUrl = ""
    var aboutEn = ""
    var aboutAr = ""
    var contactEn = ""
    var contactAr = ""
    var privacyEn = ""
    var privacyAr = ""
    var termsEn = ""
    var termsAr = ""
    var referralEnabled = false
    var referralRewardReferrerIqd = 0
    var referralRewardNewUserIqd = 0
    var complaintFlagThreshold = 3

    static let defaults = AppRemoteConfig()

    func maintenanceMessage(language: AppLanguage) -> String {
        language == .arabic ? maintenanceMessageAr : maintenanceMessageEn
    }

    func forceUpdateMessage(language: AppLanguage) -> String {
        language == .arabic ? forceUpdateMessageAr : forceUpdateMessageEn
    }

    func privacyBody(language: AppLanguage) -> String {
        language == .arabic ? privacyAr : privacyEn
    }

    func termsBody(language: AppLanguage) -> String {
        language == .arabic ? termsAr : termsEn
    }

    static func fromMap(_ data: [String: Any]?) -> AppRemoteConfig {
        guard let data, !data.isEmpty else { return .defaults }
        var config = AppRemoteConfig()
        config.maintenanceMode = readBool(data["maintenanceMode"])
        config.maintenanceMessageEn = readString(data["maintenanceMessageEn"])
        config.maintenanceMessageAr = readString(data["maintenanceMessageAr"])
        config.minAndroidBuild = readInt(data["minAndroidBuild"])
        config.minIosBuild = readInt(data["minIosBuild"])
        config.forceUpdateMessageEn = readString(data["forceUpdateMessageEn"])
        config.forceUpdateMessageAr = readString(data["forceUpdateMessageAr"])
        config.androidStoreUrl = readString(data["androidStoreUrl"])
        config.iosStoreUrl = readString(data["iosStoreUrl"])
        config.aboutEn = readString(data["aboutEn"])
        config.aboutAr = readString(data["aboutAr"])
        config.contactEn = readString(data["contactEn"])
        config.contactAr = readString(data["contactAr"])
        config.privacyEn = readString(data["privacyEn"])
        config.privacyAr = readString(data["privacyAr"])
        config.termsEn = readString(data["termsEn"])
        config.termsAr = readString(data["termsAr"])
        config.referralEnabled = readBool(data["referralEnabled"])
        config.referralRewardReferrerIqd = readInt(data["referralRewardReferrerIqd"])
        config.referralRewardNewUserIqd = readInt(data["referralRewardNewUserIqd"])
        config.complaintFlagThreshold = readInt(data["complaintFlagThreshold"], fallback: 3)
        return config
    }

    private static func readString(_ value: Any?) -> String {
        guard let value else { return "" }
        return "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readInt(_ value: Any?, fallback: Int = 0) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let text = value as? String, let parsed = Int(text) { return parsed }
        return fallback
    }

    private static func readBool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.intValue != 0 }
        if let text = value as? String {
            let lower = text.lowercased()
            return lower == "true" || lower == "1" || lower == "yes"
        }
        return false
    }
}
