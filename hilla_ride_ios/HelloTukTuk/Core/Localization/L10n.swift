import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case arabic = "ar"
    case english = "en"

    var id: String { rawValue }

    var layoutDirection: LayoutDirection {
        self == .arabic ? .rightToLeft : .leftToRight
    }
}

enum L10nKey {
    case appTitle
    case modeChooserSubtitle
    case takeRide
    case takeRideDesc
    case driveAndEarn
    case driveAndEarnDesc
    case loginTitle
    case signupTitle
    case roleCustomer
    case roleDriver
    case phoneHint
    case passwordLabel
    case rememberMe
    case forgotPassword
    case loginButton
    case createAccountButton
    case fullName
    case emailOptional
    case passwordMinLength
    case signupSuccessTitle
    case signupSuccessMessage
    case goToLogin
    case logout
    case language
    case english
    case arabic
    case phoneNumberInvalid
    case nameRequired
    case wrongPassword
    case userNotFound
    case phoneAlreadyRegistered
    case networkError
    case tooManyRequests
    case sessionActive
    case acceptTerms
    case privacyPolicy
    case termsOfService
    case welcomeSignedIn
    case driverSignupPhaseNote
    case loading
}

enum L10n {
    static func string(_ key: L10nKey, language: AppLanguage = .arabic) -> String {
        table[key]?[language] ?? table[key]?[.english] ?? String(describing: key)
    }

    private static let table: [L10nKey: [AppLanguage: String]] = [
        .appTitle: [.english: "Hello Tuk-Tuk", .arabic: "Hello Tuk-Tuk"],
        .modeChooserSubtitle: [
            .english: "Choose how you want to use Hello Tuk-Tuk today",
            .arabic: "اختر كيف تريد استخدام Hello Tuk-Tuk اليوم"
        ],
        .takeRide: [.english: "Take a ride", .arabic: "احجز مشوار"],
        .takeRideDesc: [.english: "Book a trip around Hilla city", .arabic: "احجز مشواراً في مدينة الحلة"],
        .driveAndEarn: [.english: "Enter or register as driver", .arabic: "سجّل كسائق"],
        .driveAndEarnDesc: [
            .english: "Create your driver account and start accepting rides",
            .arabic: "أنشئ حساب السائق وابدأ بقبول الرحلات"
        ],
        .loginTitle: [.english: "Log in", .arabic: "تسجيل الدخول"],
        .signupTitle: [.english: "Create account", .arabic: "إنشاء حساب"],
        .roleCustomer: [.english: "Customer", .arabic: "زبون"],
        .roleDriver: [.english: "Driver", .arabic: "سائق"],
        .phoneHint: [.english: "Phone number", .arabic: "رقم الهاتف"],
        .passwordLabel: [.english: "Password", .arabic: "كلمة المرور"],
        .rememberMe: [.english: "Remember me", .arabic: "تذكرني"],
        .forgotPassword: [.english: "Forgot password?", .arabic: "نسيت كلمة المرور؟"],
        .loginButton: [.english: "Log in", .arabic: "دخول"],
        .createAccountButton: [.english: "Create account", .arabic: "إنشاء حساب"],
        .fullName: [.english: "Full name", .arabic: "الاسم الكامل"],
        .emailOptional: [.english: "Email (optional)", .arabic: "البريد الإلكتروني (اختياري)"],
        .passwordMinLength: [
            .english: "Password must be at least 6 characters",
            .arabic: "كلمة المرور يجب أن تكون 6 أحرف على الأقل"
        ],
        .signupSuccessTitle: [.english: "Account created", .arabic: "تم إنشاء الحساب"],
        .signupSuccessMessage: [
            .english: "Your account was created. Please log in to continue.",
            .arabic: "تم إنشاء حسابك. يرجى تسجيل الدخول للمتابعة."
        ],
        .goToLogin: [.english: "Go to login", .arabic: "الذهاب لتسجيل الدخول"],
        .logout: [.english: "Log out", .arabic: "تسجيل الخروج"],
        .language: [.english: "Language", .arabic: "اللغة"],
        .english: [.english: "English", .arabic: "English"],
        .arabic: [.english: "Arabic", .arabic: "العربية"],
        .phoneNumberInvalid: [
            .english: "Enter a valid Iraqi phone number (7XXXXXXXXX)",
            .arabic: "أدخل رقم هاتف عراقي صحيح (7XXXXXXXXX)"
        ],
        .nameRequired: [.english: "Full name is required", .arabic: "الاسم الكامل مطلوب"],
        .wrongPassword: [.english: "Incorrect password", .arabic: "كلمة المرور غير صحيحة"],
        .userNotFound: [.english: "No account found for this phone number", .arabic: "لا يوجد حساب بهذا الرقم"],
        .phoneAlreadyRegistered: [
            .english: "An account with this phone number already exists",
            .arabic: "يوجد حساب مسجل بهذا الرقم"
        ],
        .networkError: [.english: "Network error. Try again.", .arabic: "خطأ في الشبكة. حاول مرة أخرى."],
        .tooManyRequests: [.english: "Too many attempts. Try again later.", .arabic: "محاولات كثيرة. حاول لاحقاً."],
        .sessionActive: [
            .english: "This account is already open on another phone.",
            .arabic: "هذا الحساب مفتوح على هاتف آخر."
        ],
        .acceptTerms: [.english: "I accept the terms and privacy policy", .arabic: "أوافق على الشروط وسياسة الخصوصية"],
        .privacyPolicy: [.english: "Privacy policy", .arabic: "سياسة الخصوصية"],
        .termsOfService: [.english: "Terms of service", .arabic: "شروط الاستخدام"],
        .welcomeSignedIn: [.english: "Signed in successfully", .arabic: "تم تسجيل الدخول بنجاح"],
        .driverSignupPhaseNote: [
            .english: "Driver photo upload will be enabled in the next build. Customer signup is fully available.",
            .arabic: "رفع صور السائق سيتوفر في الإصدار القادم. تسجيل الزبون متاح بالكامل."
        ],
        .loading: [.english: "Loading...", .arabic: "جاري التحميل..."]
    ]
}
