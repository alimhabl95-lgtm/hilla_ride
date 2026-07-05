import Foundation

enum PhoneAuthCredentials {
    static let defaultCountryCode = "+964"
    static let authEmailDomain = "hello-tiktok.app"

    static func normalizePhone(_ raw: String) -> String {
        var normalized = raw
        let arabicIndic = Array("٠١٢٣٤٥٦٧٨٩")
        let easternArabic = Array("۰۱۲۳۴۵۶۷۸۹")
        for (index, digit) in arabicIndic.enumerated() {
            normalized = normalized.replacingOccurrences(of: String(digit), with: String(index))
        }
        for (index, digit) in easternArabic.enumerated() {
            normalized = normalized.replacingOccurrences(of: String(digit), with: String(index))
        }

        var digits = normalized.filter(\.isNumber)
        if digits.hasPrefix("964") {
            digits.removeFirst(3)
        }
        if digits.hasPrefix("0") {
            digits.removeFirst()
        }
        return "\(defaultCountryCode)\(digits)"
    }

    static func toAuthEmail(_ phoneE164: String) -> String {
        let digits = phoneE164.filter(\.isNumber)
        return "\(digits)@\(authEmailDomain)"
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 6
    }

    static func isValidIraqiPhone(_ raw: String) -> Bool {
        var digits = normalizePhone(raw).filter(\.isNumber)
        if digits.hasPrefix("964") {
            digits.removeFirst(3)
        }
        if digits.hasPrefix("0") {
            digits.removeFirst()
        }
        let pattern = "^7\\d{9}$"
        return digits.range(of: pattern, options: .regularExpression) != nil
    }
}
