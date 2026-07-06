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
    case loading
    case forgotPasswordTitle
    case forgotPasswordHint
    case newPassword
    case confirmPassword
    case currentPassword
    case resetPasswordButton
    case passwordChangedTitle
    case passwordChangedMessage
    case passwordFieldsRequired
    case passwordsDoNotMatch
    case passwordResetFailed
    case profileTitle
    case changePasswordTitle
    case savePasswordButton
    case accountType
    case driverStatus
    case customerHomeTitle
    case mapsComingSoon
    case driverHomeTitle
    case driverTripsComingSoon
    case driverPendingTitle
    case driverPendingMessage
    case driverRejectedTitle
    case driverRejectedMessage
    case driverBlockedTitle
    case driverBlockedMessage
    case driverSignupTitle
    case driverSignupSubtitle
    case age
    case vehiclePlate
    case vehicleColor
    case idPhotoLabel
    case profilePhotoLabel
    case tapToUploadPhoto
    case submitDriverApplication
    case driverSignupSuccessTitle
    case driverSignupSuccessMessage
    case driverMinAge
    case vehiclePlateRequired
    case vehicleColorRequired
    case registrationPhotosRequired
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
        .loading: [.english: "Loading...", .arabic: "جاري التحميل..."],
        .forgotPasswordTitle: [.english: "Reset password", .arabic: "إعادة تعيين كلمة المرور"],
        .forgotPasswordHint: [
            .english: "Enter your phone number and choose a new password.",
            .arabic: "أدخل رقم هاتفك واختر كلمة مرور جديدة."
        ],
        .newPassword: [.english: "New password", .arabic: "كلمة المرور الجديدة"],
        .confirmPassword: [.english: "Confirm password", .arabic: "تأكيد كلمة المرور"],
        .currentPassword: [.english: "Current password", .arabic: "كلمة المرور الحالية"],
        .resetPasswordButton: [.english: "Reset password", .arabic: "إعادة تعيين كلمة المرور"],
        .passwordChangedTitle: [.english: "Password updated", .arabic: "تم تحديث كلمة المرور"],
        .passwordChangedMessage: [
            .english: "Your password was updated successfully.",
            .arabic: "تم تحديث كلمة المرور بنجاح."
        ],
        .passwordFieldsRequired: [
            .english: "Please fill in all password fields.",
            .arabic: "يرجى تعبئة جميع حقول كلمة المرور."
        ],
        .passwordsDoNotMatch: [
            .english: "Passwords do not match.",
            .arabic: "كلمتا المرور غير متطابقتين."
        ],
        .passwordResetFailed: [
            .english: "Could not reset password. Try again.",
            .arabic: "تعذر إعادة تعيين كلمة المرور. حاول مرة أخرى."
        ],
        .profileTitle: [.english: "Profile", .arabic: "الملف الشخصي"],
        .changePasswordTitle: [.english: "Change password", .arabic: "تغيير كلمة المرور"],
        .savePasswordButton: [.english: "Save password", .arabic: "حفظ كلمة المرور"],
        .accountType: [.english: "Account type", .arabic: "نوع الحساب"],
        .driverStatus: [.english: "Driver status", .arabic: "حالة السائق"],
        .customerHomeTitle: [.english: "Ready to ride", .arabic: "جاهز للمشوار"],
        .mapsComingSoon: [
            .english: "Google Maps and ride booking arrive in the next TestFlight build.",
            .arabic: "خرائط Google وحجز المشاوير في الإصدار القادم على TestFlight."
        ],
        .driverHomeTitle: [.english: "Driver dashboard", .arabic: "لوحة السائق"],
        .driverTripsComingSoon: [
            .english: "Trip requests and navigation arrive in the next TestFlight build.",
            .arabic: "طلبات الرحلات والملاحة في الإصدار القادم على TestFlight."
        ],
        .driverPendingTitle: [.english: "Application under review", .arabic: "طلبك قيد المراجعة"],
        .driverPendingMessage: [
            .english: "Your driver application is being reviewed by our team. You will be notified once approved.",
            .arabic: "طلب السائق قيد المراجعة. سيتم إشعارك عند الموافقة."
        ],
        .driverRejectedTitle: [.english: "Application not approved", .arabic: "لم تتم الموافقة على الطلب"],
        .driverRejectedMessage: [
            .english: "Your driver application was not approved. Contact support for help.",
            .arabic: "لم تتم الموافقة على طلب السائق. تواصل مع الدعم للمساعدة."
        ],
        .driverBlockedTitle: [.english: "Account blocked", .arabic: "الحساب محظور"],
        .driverBlockedMessage: [
            .english: "Your driver account has been blocked. Contact support.",
            .arabic: "تم حظر حساب السائق. تواصل مع الدعم."
        ],
        .driverSignupTitle: [.english: "Driver registration", .arabic: "تسجيل السائق"],
        .driverSignupSubtitle: [
            .english: "Upload your ID and profile photo. Our team will review your application.",
            .arabic: "ارفع صورة الهوية والصورة الشخصية. سيراجع فريقنا طلبك."
        ],
        .age: [.english: "Age", .arabic: "العمر"],
        .vehiclePlate: [.english: "Vehicle plate", .arabic: "رقم اللوحة"],
        .vehicleColor: [.english: "Vehicle color", .arabic: "لون المركبة"],
        .idPhotoLabel: [.english: "ID photo", .arabic: "صورة الهوية"],
        .profilePhotoLabel: [.english: "Profile photo", .arabic: "الصورة الشخصية"],
        .tapToUploadPhoto: [.english: "Tap to upload photo", .arabic: "اضغط لرفع الصورة"],
        .submitDriverApplication: [.english: "Submit application", .arabic: "إرسال الطلب"],
        .driverSignupSuccessTitle: [.english: "Application submitted", .arabic: "تم إرسال الطلب"],
        .driverSignupSuccessMessage: [
            .english: "Your driver application was submitted. Please log in after approval.",
            .arabic: "تم إرسال طلب السائق. يرجى تسجيل الدخول بعد الموافقة."
        ],
        .driverMinAge: [
            .english: "Drivers must be at least 18 years old.",
            .arabic: "يجب أن يكون عمر السائق 18 سنة على الأقل."
        ],
        .vehiclePlateRequired: [.english: "Vehicle plate is required.", .arabic: "رقم اللوحة مطلوب."],
        .vehicleColorRequired: [.english: "Vehicle color is required.", .arabic: "لون المركبة مطلوب."],
        .registrationPhotosRequired: [
            .english: "ID photo and profile photo are required.",
            .arabic: "صورة الهوية والصورة الشخصية مطلوبتان."
        ]
    ]
}
