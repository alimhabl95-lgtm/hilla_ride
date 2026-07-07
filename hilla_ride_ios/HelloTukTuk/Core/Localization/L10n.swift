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
    case welcomeMessage
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
    case pickupLabel
    case destinationLabel
    case bookRide
    case bookRideTitle
    case selectPickup
    case selectDestination
    case useMyLocation
    case subDistrict
    case estimatedFare
    case distance
    case confirmBooking
    case findingDriver
    case findingDriverHint
    case retryDriverSearch
    case waitingForDriver
    case waitingForDriverHint
    case driverAssignedTitle
    case waitingDriverAccept
    case driverOnTheWay
    case rideInProgress
    case awaitingCashPayment
    case cancelRide
    case outOfService
    case pickupDestinationSame
    case activeRideExists
    case noDriversAvailable
    case mapsUnavailable
    case myLocation
    case mapPinDestination
    case locationUnavailable
    case goOnline
    case goOffline
    case driverWorkAreaRequired
    case driverGoOnlineHint
    case driverWaitingForRequests
    case acceptRide
    case rejectRide
    case startRide
    case endRide
    case confirmCashCollected
    case newRideOffer
    case rideAccepted
    case tripCompletedTitle
    case paymentMethodCash
    case ratingSubmitted
    case rateYourDriver
    case feedbackOptional
    case submitRating
    case done
    case rideCancelled
    case searchPlacesHint
    case finalFare
    case noDriversInDistrict
    case rideChatTitle
    case chatHint
    case send
    case messageSendFailed
    case ok
    case supportTitle
    case supportMessageHint
    case supportMessageSent
    case rideHistoryTitle
    case noRideHistory
    case editProfileTitle
    case saveProfileButton
    case profileSaved
    case accountBlockedTitle
    case accountBlockedMessage
    case driverAcceptedAlertTitle
    case driverAcceptedAlertBody
    case chatWithDriver
    case chatWithCustomer
    case savedPlacesTitle
    case savedPlacesEmptyHint
    case savedPlaceAdded
    case deleteSavedPlace
    case announcementsTitle
    case announcementsEmpty
    case legalDocumentsTitle
    case driverMonthlyPrizeTitle
    case yourEarningsTitle
    case completedRidesCount
    case driverNetEarnings
    case owedToPlatformLabel
    case pendingBonusLabel
    case supportPreviousMessages
    case confirmPinLocation
    case pickOnMap
    case restoreProfileTitle
    case restoreProfileMessage
    case restoreProfileAction
    case useDifferentAccount
    case customerProfileTitle
    case customerProfileHint
    case profileFieldsRequired
    case gender
    case genderOptional
    case genderMale
    case genderFemale
    case cancelledRidesCount
    case cancel
}

enum L10n {
    static func string(_ key: L10nKey, language: AppLanguage = .arabic) -> String {
        table[key]?[language] ?? table[key]?[.english] ?? String(describing: key)
    }

    static func promoDiscountApplied(code: String, amount: String, language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(code): you save \(amount)"
        case .arabic:
            return "\(code): توفر \(amount)"
        }
    }

    static func driverMonthlyRideCount(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .english: return "\(count) rides this month"
        case .arabic: return "\(count) مشاوير هذا الشهر"
        }
    }

    static func driverMonthlyRank(_ rank: Int, _ total: Int, language: AppLanguage) -> String {
        switch language {
        case .english: return "Rank \(rank) of \(total) drivers"
        case .arabic: return "الترتيب \(rank) من \(total) سائق"
        }
    }

    static func driverMonthlyPrizeAmount(_ amount: String, language: AppLanguage) -> String {
        switch language {
        case .english: return "Monthly prize: \(amount)"
        case .arabic: return "جائزة الشهر: \(amount)"
        }
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
        .welcomeMessage: [.english: "Welcome!", .arabic: "أهلاً بكم!"],
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
        .customerHomeTitle: [.english: "Book a ride", .arabic: "احجز مشوار"],
        .mapsComingSoon: [
            .english: "More map features arrive in upcoming TestFlight builds.",
            .arabic: "المزيد من ميزات الخريطة في إصدارات TestFlight القادمة."
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
        ],
        .pickupLabel: [.english: "Pickup", .arabic: "نقطة الانطلاق"],
        .destinationLabel: [.english: "Destination", .arabic: "الوجهة"],
        .bookRide: [.english: "Book ride", .arabic: "احجز مشوار"],
        .bookRideTitle: [.english: "Confirm your ride", .arabic: "تأكيد المشوار"],
        .selectPickup: [.english: "Tap to search pickup", .arabic: "اضغط للبحث عن نقطة الانطلاق"],
        .selectDestination: [.english: "Tap to search or long-press map", .arabic: "اضغط للبحث أو اضغط مطولاً على الخريطة"],
        .useMyLocation: [.english: "Use my location", .arabic: "استخدم موقعي"],
        .subDistrict: [.english: "Area", .arabic: "المنطقة"],
        .estimatedFare: [.english: "Estimated fare", .arabic: "الأجرة التقديرية"],
        .distance: [.english: "Distance", .arabic: "المسافة"],
        .confirmBooking: [.english: "Confirm booking", .arabic: "تأكيد الحجز"],
        .findingDriver: [.english: "Finding a driver", .arabic: "جاري البحث عن سائق"],
        .findingDriverHint: [
            .english: "We are matching you with nearby drivers in your area.",
            .arabic: "نبحث عن سائق قريب في منطقتك."
        ],
        .retryDriverSearch: [.english: "Search again", .arabic: "إعادة البحث"],
        .waitingForDriver: [.english: "Waiting for driver", .arabic: "بانتظار السائق"],
        .waitingForDriverHint: [
            .english: "A driver has been notified. Waiting for acceptance.",
            .arabic: "تم إشعار السائق. بانتظار القبول."
        ],
        .driverAssignedTitle: [.english: "Driver assigned", .arabic: "تم تعيين السائق"],
        .waitingDriverAccept: [
            .english: "Waiting for driver to accept…",
            .arabic: "بانتظار قبول السائق للرحلة…"
        ],
        .driverOnTheWay: [.english: "Driver on the way", .arabic: "السائق في الطريق"],
        .rideInProgress: [.english: "Ride in progress", .arabic: "المشوار جاري"],
        .awaitingCashPayment: [.english: "Pay cash to driver", .arabic: "ادفع نقداً للسائق"],
        .cancelRide: [.english: "Cancel ride", .arabic: "إلغاء المشوار"],
        .outOfService: [
            .english: "This trip is outside the service area or max distance.",
            .arabic: "هذا المشوار خارج نطاق الخدمة أو أقصى مسافة."
        ],
        .pickupDestinationSame: [
            .english: "Pickup and destination must be at least 100 m apart.",
            .arabic: "يجب أن تبعد نقطة الانطلاق عن الوجهة 100 متر على الأقل."
        ],
        .activeRideExists: [
            .english: "You already have an active ride.",
            .arabic: "لديك مشوار نشط بالفعل."
        ],
        .noDriversAvailable: [
            .english: "No drivers are online in this area right now.",
            .arabic: "لا يوجد سائقون متصلون في هذه المنطقة حالياً."
        ],
        .mapsUnavailable: [
            .english: "Google Maps is not configured for this build.",
            .arabic: "خرائط Google غير مهيأة في هذا الإصدار."
        ],
        .myLocation: [.english: "My location", .arabic: "موقعي الحالي"],
        .mapPinDestination: [.english: "Map destination", .arabic: "وجهة على الخريطة"],
        .locationUnavailable: [
            .english: "Could not get your location. Allow location access or pick on the map.",
            .arabic: "تعذر الحصول على موقعك. اسمح بالوصول للموقع أو اختر على الخريطة."
        ],
        .goOnline: [.english: "Online", .arabic: "متصل"],
        .goOffline: [.english: "Offline", .arabic: "غير متصل"],
        .driverWorkAreaRequired: [
            .english: "Your work area is not assigned. Contact support.",
            .arabic: "لم يتم تعيين منطقة عملك. تواصل مع الدعم."
        ],
        .driverGoOnlineHint: [
            .english: "Turn on the switch to receive ride requests.",
            .arabic: "فعّل المفتاح لاستقبال طلبات المشاوير."
        ],
        .driverWaitingForRequests: [
            .english: "You are online. Waiting for ride requests…",
            .arabic: "أنت متصل. بانتظار طلبات المشاوير…"
        ],
        .acceptRide: [.english: "Accept ride", .arabic: "قبول المشوار"],
        .rejectRide: [.english: "Reject", .arabic: "رفض"],
        .startRide: [.english: "Start ride", .arabic: "بدء المشوار"],
        .endRide: [.english: "End ride", .arabic: "إنهاء المشوار"],
        .confirmCashCollected: [.english: "Cash collected", .arabic: "تم استلام النقد"],
        .newRideOffer: [.english: "New ride request", .arabic: "طلب مشوار جديد"],
        .rideAccepted: [.english: "Ride accepted", .arabic: "تم قبول المشوار"],
        .tripCompletedTitle: [.english: "Trip completed", .arabic: "اكتمل المشوار"],
        .paymentMethodCash: [.english: "Cash payment", .arabic: "دفع نقداً"],
        .ratingSubmitted: [.english: "Thank you for your rating!", .arabic: "شكراً لتقييمك!"],
        .rateYourDriver: [.english: "Rate your driver", .arabic: "قيّم السائق"],
        .feedbackOptional: [.english: "Feedback (optional)", .arabic: "ملاحظات (اختياري)"],
        .submitRating: [.english: "Submit rating", .arabic: "إرسال التقييم"],
        .done: [.english: "Done", .arabic: "تم"],
        .rideCancelled: [.english: "Ride cancelled", .arabic: "تم إلغاء المشوار"],
        .searchPlacesHint: [.english: "Search places in Hilla", .arabic: "ابحث عن أماكن في الحلة"],
        .finalFare: [.english: "Your fare", .arabic: "أجرتك"],
        .noDriversInDistrict: [
            .english: "No drivers are online in this city right now. We will keep searching.",
            .arabic: "لا يوجد سائقون متصلون في هذه المدينة حالياً. سنواصل البحث."
        ],
        .rideChatTitle: [.english: "Ride chat", .arabic: "محادثة المشوار"],
        .chatHint: [.english: "Type a message", .arabic: "اكتب رسالة"],
        .send: [.english: "Send", .arabic: "إرسال"],
        .supportTitle: [.english: "Support", .arabic: "الدعم"],
        .supportMessageHint: [.english: "Describe your issue", .arabic: "صف مشكلتك"],
        .supportMessageSent: [.english: "Message sent. We will contact you soon.", .arabic: "تم إرسال الرسالة. سنتواصل معك قريباً."],
        .rideHistoryTitle: [.english: "My trips", .arabic: "رحلاتي"],
        .noRideHistory: [.english: "No trips yet", .arabic: "لا توجد رحلات بعد"],
        .editProfileTitle: [.english: "Edit profile", .arabic: "تعديل الملف"],
        .saveProfileButton: [.english: "Save profile", .arabic: "حفظ الملف"],
        .profileSaved: [.english: "Profile updated", .arabic: "تم تحديث الملف"],
        .accountBlockedTitle: [.english: "Account blocked", .arabic: "الحساب محظور"],
        .accountBlockedMessage: [
            .english: "Your account has been blocked. Contact support for help.",
            .arabic: "تم حظر حسابك. تواصل مع الدعم للمساعدة."
        ],
        .driverAcceptedAlertTitle: [.english: "Driver accepted", .arabic: "قبل السائق المشوار"],
        .driverAcceptedAlertBody: [.english: "Your driver is on the way", .arabic: "السائق في الطريق إليك"],
        .chatWithDriver: [.english: "Message from driver", .arabic: "رسالة من السائق"],
        .chatWithCustomer: [.english: "Message from customer", .arabic: "رسالة من الزبون"],
        .savedPlacesTitle: [.english: "Saved places", .arabic: "الأماكن المحفوظة"],
        .savedPlacesEmptyHint: [.english: "Save places from search to reuse them quickly.", .arabic: "احفظ الأماكن من البحث لاستخدامها لاحقاً."],
        .savedPlaceAdded: [.english: "Place saved", .arabic: "تم حفظ المكان"],
        .deleteSavedPlace: [.english: "Remove", .arabic: "حذف"],
        .announcementsTitle: [.english: "Announcements", .arabic: "الإعلانات"],
        .announcementsEmpty: [.english: "No announcements yet", .arabic: "لا توجد إعلانات بعد"],
        .legalDocumentsTitle: [.english: "Legal documents", .arabic: "المستندات القانونية"],
        .driverMonthlyPrizeTitle: [.english: "Monthly prize", .arabic: "جائزة الشهر"],
        .yourEarningsTitle: [.english: "Your earnings", .arabic: "أرباحك"],
        .completedRidesCount: [.english: "Completed rides", .arabic: "المشاوير المكتملة"],
        .driverNetEarnings: [.english: "Net earnings", .arabic: "صافي الأرباح"],
        .owedToPlatformLabel: [.english: "Owed to platform", .arabic: "المستحق للمنصة"],
        .pendingBonusLabel: [.english: "Pending bonus", .arabic: "مكافأة معلّقة"],
        .supportPreviousMessages: [.english: "Previous messages", .arabic: "الرسائل السابقة"],
        .confirmPinLocation: [.english: "Confirm location", .arabic: "تأكيد الموقع"],
        .pickOnMap: [.english: "Pick on map", .arabic: "اختر على الخريطة"],
        .restoreProfileTitle: [.english: "Restore your profile", .arabic: "استعادة ملفك الشخصي"],
        .restoreProfileMessage: [
            .english: "Your account exists but profile data is missing. Enter your name to continue.",
            .arabic: "حسابك موجود لكن بيانات الملف مفقودة. أدخل اسمك للمتابعة."
        ],
        .restoreProfileAction: [.english: "Restore profile", .arabic: "استعادة الملف"],
        .useDifferentAccount: [.english: "Use a different account", .arabic: "استخدام حساب آخر"],
        .customerProfileTitle: [.english: "Complete your profile", .arabic: "أكمل ملفك الشخصي"],
        .customerProfileHint: [
            .english: "Add your name and age before booking rides.",
            .arabic: "أضف اسمك وعمرك قبل حجز المشاوير."
        ],
        .profileFieldsRequired: [
            .english: "Name and age are required.",
            .arabic: "الاسم والعمر مطلوبان."
        ],
        .gender: [.english: "Gender", .arabic: "الجنس"],
        .genderOptional: [.english: "Prefer not to say", .arabic: "لا أرغب بالإفصاح"],
        .genderMale: [.english: "Male", .arabic: "ذكر"],
        .genderFemale: [.english: "Female", .arabic: "أنثى"],
        .cancelledRidesCount: [.english: "Cancelled rides", .arabic: "الرحلات الملغاة"],
        .cancel: [.english: "Cancel", .arabic: "إلغاء"],
        .messageSendFailed: [.english: "Couldn't send message", .arabic: "تعذّر إرسال الرسالة"],
        .ok: [.english: "OK", .arabic: "حسناً"]
    ]
}
