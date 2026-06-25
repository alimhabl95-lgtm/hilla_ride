// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Hello Tuk-Tuk';

  @override
  String get welcomeMessage => 'أهلاً بكم!';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get selectRole => 'كيف ستستخدم Hello Tuk-Tuk؟';

  @override
  String get roleCustomer => 'زبون';

  @override
  String get roleCustomerDesc => 'اطلب رحلات داخل الحلة';

  @override
  String get roleDriver => 'سائق';

  @override
  String get roleDriverDesc => 'اقبل الرحلات واكسب المال';

  @override
  String get roleManager => 'مدير';

  @override
  String get roleManagerDesc => 'وافق على السائقين وأدر الأسطول';

  @override
  String get phoneLogin => 'تسجيل الدخول بالهاتف';

  @override
  String get phoneHint => 'رقم الهاتف';

  @override
  String get sendCode => 'إرسال رمز التحقق';

  @override
  String get verifyCode => 'تحقق من الرمز';

  @override
  String get otpHint => 'رمز من 6 أرقام';

  @override
  String get customerProfileTitle => 'ملفك الشخصي';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get age => 'العمر';

  @override
  String get gender => 'الجنس (اختياري)';

  @override
  String get male => 'ذكر';

  @override
  String get female => 'أنثى';

  @override
  String get pickup => 'نقطة الانطلاق';

  @override
  String get destination => 'الوجهة';

  @override
  String get searchPlaces => 'ابحث عن أماكن في الحلة';

  @override
  String get noPlacesFound =>
      'لم يتم العثور على أماكن. جرّب اسمًا أقصر أو استخدم تحديد على الخريطة.';

  @override
  String get searchAction => 'بحث';

  @override
  String get searchPlacesHint =>
      'اكتب بالعربية ثم اضغط بحث. على المحاكي: Win+Space لاختيار لوحة العربية';

  @override
  String get searchFieldHint => 'ابحث أو اكتب بالإنجليزية (hospital, market)';

  @override
  String get searchTapPlaceHint =>
      'اضغط على مكان من القائمة، أو اختر تصنيفاً أدناه';

  @override
  String placesInHillaCount(int count) {
    return '$count مكان في الحلة';
  }

  @override
  String get pinOnMap => 'حدد على الخريطة';

  @override
  String get requestRide => 'اطلب رحلة';

  @override
  String get searchingDriver => 'جاري البحث عن سائق...';

  @override
  String get driverFound => 'السائق في الطريق';

  @override
  String get noDriversAvailable => 'لا يوجد سائقون متاحون حالياً. حاول لاحقاً.';

  @override
  String get liveDriverLocation => 'موقع السائق المباشر';

  @override
  String get driverRegistration => 'تسجيل السائق';

  @override
  String get vehicleType => 'نوع المركبة';

  @override
  String get vehiclePlate => 'رقم اللوحة';

  @override
  String get licenseNumber => 'رقم الرخصة';

  @override
  String get submitForApproval => 'إرسال للموافقة';

  @override
  String get pendingApprovalTitle => 'بانتظار موافقة المدير';

  @override
  String get pendingApprovalBody =>
      'سيتم تفعيل حسابك بعد مراجعة المدير لمعلوماتك.';

  @override
  String get rejectedTitle => 'تم رفض التسجيل';

  @override
  String get goOnline => 'اتصل بالعمل';

  @override
  String get goOffline => 'قطع الاتصال';

  @override
  String get newRideRequest => 'طلب رحلة جديد';

  @override
  String get acceptRide => 'قبول الرحلة';

  @override
  String get rejectRide => 'رفض الرحلة';

  @override
  String get activeRideExists =>
      'لديك رحلة نشطة بالفعل. أنهِها أو ألغِها قبل حجز رحلة أخرى.';

  @override
  String get managerTitle => 'موافقات السائقين';

  @override
  String get approve => 'موافقة';

  @override
  String get reject => 'رفض';

  @override
  String get noPendingDrivers => 'لا توجد طلبات سائقين معلقة';

  @override
  String get noDriversYet => 'لا يوجد سائقون مسجلون بعد.';

  @override
  String get pendingDriversLoadError =>
      'تعذّر تحميل السائقين. انشر قواعد Firestore من firestore.rules في Firebase Console → Firestore → Rules ثم Publish. تأكد أيضاً أنك مسجل دخول كمدير.';

  @override
  String get checkAllDriversTab =>
      'نصيحة: افتح تبويب كل السائقين لرؤية جميع السائقين المسجلين.';

  @override
  String get unnamedDriver => 'سائق (الاسم غير محفوظ)';

  @override
  String get routeToPickup => 'إلى نقطة العميل';

  @override
  String get routeToDestination => 'من الانطلاق إلى الوجهة';

  @override
  String get firebaseSetupRequired =>
      'Firebase غير مهيأ. نفّذ: flutterfire configure';

  @override
  String get currentLocation => 'موقعي الحالي';

  @override
  String get confirmLocation => 'تأكيد الموقع';

  @override
  String get tapMapToPin => 'اضغط على الخريطة لاختيار موقع';

  @override
  String get rideFrom => 'من';

  @override
  String get rideTo => 'إلى';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get wrongRoleTitle => 'تطبيق خاطئ لهذا الحساب';

  @override
  String wrongRoleBody(String expectedRole, String actualRole) {
    return 'هذا التطبيق مخصص لحسابات $expectedRole. أنت مسجل كـ $actualRole.';
  }

  @override
  String get adminPanelTitle => 'Hello Tuk-Tuk Admin';

  @override
  String get pendingDriversTab => 'المعلقة';

  @override
  String get activeRidesTab => 'الرحلات النشطة';

  @override
  String get allDriversTab => 'كل السائقين';

  @override
  String get rideHistoryTab => 'السجل';

  @override
  String get noActiveRides => 'لا توجد رحلات نشطة';

  @override
  String get cashFare => 'أجرة نقداً';

  @override
  String get paymentMethodCash => 'الدفع: نقداً فقط';

  @override
  String get startRide => 'بدء الرحلة';

  @override
  String get endRide => 'إنهاء الرحلة';

  @override
  String get cashCollected => 'تم استلام النقد';

  @override
  String get waitingCustomerCashConfirm => 'بانتظار تأكيد الزبون للدفع النقدي';

  @override
  String get payCash => 'دفعت نقداً';

  @override
  String get cashPaymentConfirmed => 'تم تأكيد الدفع النقدي';

  @override
  String get waitingForRides => 'بانتظار طلبات الرحلات';

  @override
  String get rideCompleted => 'اكتملت الرحلة';

  @override
  String get modeChooserSubtitle => 'اختر كيف تريد استخدام Hello Tuk-Tuk اليوم';

  @override
  String get takeRide => 'خذ رحلة';

  @override
  String get takeRideDesc => 'احجز رحلة داخل مدينة الحلة';

  @override
  String get driveAndEarn => 'ادخل أو سجّل كسائق';

  @override
  String get driveAndEarnDesc => 'أنشئ حساب السائق وابدأ بقبول الرحلات';

  @override
  String get accountAlreadyOpenElsewhere =>
      'هذا الحساب مفتوح على هاتف آخر. سجّل الخروج منه أولاً ثم حاول مرة أخرى.';

  @override
  String get accountLoggedInElsewhere =>
      'تم تسجيل خروجك لأن الحساب فُتح على هاتف آخر.';

  @override
  String get switchMode => 'تغيير الوضع';

  @override
  String get phoneLoginModeHint => 'سجّل الدخول برقم هاتفك لإكمال التسجيل';

  @override
  String get managerAccessDenied => 'لوحة الإدارة مخصصة لحسابات المدير فقط.';

  @override
  String get phoneNumberInvalid =>
      'أدخل رقم هاتف عراقي صحيح (9 أرقام بعد +964).';

  @override
  String get phoneHintExample => '7901234567';

  @override
  String get phoneVerificationFailed =>
      'فشل التحقق من الهاتف. تحقق من إعداد Firebase وحاول مرة أخرى.';

  @override
  String get webPhoneLoginHint =>
      'على الويب، يحتاج تسجيل الدخول إلى Firebase وreCAPTCHA. للاختبار استخدم هاتف Android أو محاكي.';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get rememberMe => 'تذكرني';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginButton => 'تسجيل الدخول';

  @override
  String get createAccountButton => 'إنشاء حساب';

  @override
  String get loginFailed => 'فشل تسجيل الدخول. تحقق من الهاتف وكلمة المرور.';

  @override
  String get signupTitle => 'إنشاء حساب';

  @override
  String get emailOptional => 'البريد الإلكتروني (اختياري)';

  @override
  String get passwordMinLength => 'كلمة المرور 6 أحرف على الأقل.';

  @override
  String get nameRequired => 'يرجى إدخال الاسم الكامل.';

  @override
  String get signupFailed => 'فشل إنشاء الحساب. جرّب رقم هاتف آخر.';

  @override
  String get resetEmailSent => 'تم إرسال رابط إعادة تعيين كلمة المرور.';

  @override
  String get resetFailed => 'تعذّر إرسال رابط إعادة التعيين.';

  @override
  String get forgotPasswordHint =>
      'أدخل رقم هاتفك أو بريدك لإعادة تعيين كلمة المرور.';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get bookRideTitle => 'حجز رحلة';

  @override
  String get minutes => 'د';

  @override
  String get bookNowButton => 'احجز الآن';

  @override
  String get bookRideFailed =>
      'تعذّر إكمال الحجز. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get currentRideTitle => 'الرحلة الحالية';

  @override
  String get pickupDestinationRequired => 'اختر نقطة الانطلاق والوجهة أولاً.';

  @override
  String get pickupDestinationMustDiffer =>
      'يجب أن تكون نقطة الانطلاق مختلفة عن الوجهة (100 متر على الأقل).';

  @override
  String get districtLabel => 'القضاء';

  @override
  String get subDistrictLabel => 'الناحية';

  @override
  String get selectSubDistrictHint => 'اختر الناحية';

  @override
  String get selectSubDistrictRequired => 'يرجى اختيار الناحية أولاً.';

  @override
  String get fixedCustomerDistrictLabel => 'قضاء الهاشمية';

  @override
  String get whereTo => 'إلى أين؟';

  @override
  String get bookRideButton => 'احجز رحلة';

  @override
  String get findingDriverTitle => 'البحث عن سائق';

  @override
  String get findingDriverSubtitle =>
      'إشعار السائقين المتصلين في مدينتك. أول من يقبل يحصل على الرحلة.';

  @override
  String get driverAssignedTitle => 'تم تعيين السائق';

  @override
  String get waitingDriverAccept => 'بانتظار قبول السائق للرحلة…';

  @override
  String get trackDriverTitle => 'تتبع السائق';

  @override
  String get tripInProgress => 'الرحلة جارية';

  @override
  String get tripCompletedTitle => 'اكتملت الرحلة';

  @override
  String get doneButton => 'تم';

  @override
  String searchRegionHint(String region) {
    return 'البحث محصور في $region';
  }

  @override
  String placesInRegionCount(int count, String region) {
    return '$count مكان في $region';
  }

  @override
  String get searchOutsideRegion => 'هذا الموقع خارج المنطقة المحددة.';

  @override
  String get googleMapsKeyRequired =>
      'أضف مفتاح Google Maps لتفعيل البحث عبر الإنترنت.';

  @override
  String get placesApiDenied =>
      'البحث عبر الإنترنت محدود. النتائج أدناه من OpenStreetMap في هذه المنطقة.';

  @override
  String get locatingCurrentPosition => 'جاري تحديد موقعك…';

  @override
  String get searchUsingOpenStreetMap =>
      'عرض الأماكن من OpenStreetMap في هذه المنطقة.';

  @override
  String get locationServiceDisabled =>
      'فعّل خدمة الموقع (GPS) من إعدادات الهاتف.';

  @override
  String get locationPermissionDenied =>
      'التطبيق يحتاج إذن الموقع. اسمح به من إعدادات التطبيق.';

  @override
  String get locationFetchFailed =>
      'تعذّر تحديد موقع GPS. اضغط أيقونة الموقع للمحاولة مرة أخرى.';

  @override
  String get authEmailPasswordDisabled =>
      'Enable Email/Password in Firebase Console: Authentication → Sign-in method → Email/Password → Enable.';

  @override
  String get authEmailAlreadyInUse =>
      'رقم الهاتف مسجل مسبقاً. جرّب تسجيل الدخول.';

  @override
  String get restoreProfileTitle => 'استعادة الحساب';

  @override
  String get restoreProfileMessage =>
      'تسجيل الدخول لا يزال نشطاً لكن بيانات ملفك حُذفت من الخادم. أدخل اسمك أدناه لاستعادة الوصول.';

  @override
  String restoreProfileRoleHint(String role) {
    return 'نوع الحساب: $role';
  }

  @override
  String get restoreProfileAction => 'استعادة الحساب';

  @override
  String get useDifferentAccount => 'استخدام حساب آخر';

  @override
  String get assistantProfileMissingHint =>
      'يجب على المدير إعادة إنشاء حسابات المساعدين من لوحة الإدارة.';

  @override
  String get authTooManyRequests =>
      'محاولات كثيرة. انتظر دقائق ثم حاول مرة أخرى.';

  @override
  String get authNetworkError =>
      'خطأ في الشبكة. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get dragMapToSelectPin =>
      'حرّك الخريطة لوضع الدبوس على الموقع المطلوب.';

  @override
  String get pinStreetNameRequired =>
      'تعذر قراءة اسم الشارع. حرّك الدبوس قليلاً ثم حاول مرة أخرى.';

  @override
  String get outOfServiceZone => 'خارج نطاق الخدمة';

  @override
  String get calculatingFare => 'جاري حساب الأجرة…';

  @override
  String get fareCalculationFailed =>
      'تعذّر حساب الأجرة. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get drivingDistance => 'مسافة القيادة';

  @override
  String maxDistanceLimit(String km) {
    return 'أقصى مسافة للرحلة $km كم.';
  }

  @override
  String get pricingTab => 'التسعير';

  @override
  String get pricingRulesTitle => 'قواعد التسعير';

  @override
  String get pricingRulesHint =>
      'يتم حساب الأجرة حسب مسافة القيادة من Google Maps. الرحلات التي تتجاوز الحد الأقصى للمسافة مرفوضة.';

  @override
  String get maxDistanceKmLabel => 'أقصى مسافة';

  @override
  String get priceBracketsTitle => 'شرائح المسافة';

  @override
  String get fromKm => 'من (كم)';

  @override
  String get toKm => 'إلى (كم)';

  @override
  String get priceIqd => 'السعر (د.ع)';

  @override
  String get savePricingRules => 'حفظ قواعد التسعير';

  @override
  String get pricingSaved => 'تم حفظ قواعد التسعير.';

  @override
  String get pricingSaveFailed =>
      'تعذّر حفظ قواعد التسعير. تحقق من القيم وحاول مرة أخرى.';

  @override
  String get pricingSavePermissionDenied =>
      'Firebase منع الحفظ. انشر firestore.rules وCloud Functions (savePricingConfig)، وتأكد أن role حسابك في مجموعة users هو manager أو assistant مع صلاحية pricing.';

  @override
  String get pricingInvalidValues =>
      'تحقق من أن جميع حقول المسافة والسعر تحتوي أرقاماً صحيحة.';

  @override
  String get estimatedDistanceNote =>
      'مسافة تقريبية — تعذّر تحميل مسار القيادة الدقيق.';

  @override
  String get noRideHistory => 'لا يوجد سجل رحلات بعد.';

  @override
  String get chatWithDriver => 'محادثة مع السائق';

  @override
  String get chatWithCustomer => 'محادثة مع الزبون';

  @override
  String get noChatMessages => 'لا توجد رسائل بعد. ابدأ المحادثة!';

  @override
  String get typeMessage => 'اكتب رسالة…';

  @override
  String get holdToRecordVoice => 'اضغط الميكروفون للتسجيل';

  @override
  String get tapToRecordVoice => 'اضغط للتسجيل';

  @override
  String get stopRecording => 'إيقاف وإرسال';

  @override
  String get voiceMessageTooShort => 'استمر بالتسجيل قليلاً ثم اضغط إيقاف.';

  @override
  String get recordingVoice => 'جاري التسجيل…';

  @override
  String get voiceMessageLabel => 'رسالة صوتية';

  @override
  String get microphonePermissionRequired =>
      'يلزم إذن الميكروفون لإرسال الرسائل الصوتية.';

  @override
  String get voiceMessageSendFailed =>
      'تعذر إرسال الرسالة الصوتية. حاول مرة أخرى.';

  @override
  String get voiceMessagePlaybackFailed => 'تعذر تشغيل الرسالة الصوتية.';

  @override
  String get messageSendFailed =>
      'تعذر إرسال الرسالة. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get chatLoadFailed => 'تعذر تحميل رسائل المحادثة.';

  @override
  String get microphonePermissionWebHint =>
      'اسمح للمتصفح باستخدام الميكروفون ثم حاول مرة أخرى.';

  @override
  String get driverWorkDistrictLabel => 'مدينة العمل';

  @override
  String get driverWorkDistrictHint =>
      'عيّن مدينة عمل للسائق. يستلم طلبات الرحلات في هذه المدينة فقط. أول سائق يقبل يأخذ الرحلة.';

  @override
  String get driverWorkDistrictRequired =>
      'يجب على المدير تعيين مدينة عمل قبل أن يستلم السائق الطلبات.';

  @override
  String get driverWorkDistrictSaved => 'تم تحديث مدينة عمل السائق.';

  @override
  String get saveDriverWorkDistrict => 'حفظ مدينة العمل';

  @override
  String get noDriversInDistrict =>
      'لا يوجد سائقون متصلون في هذه المدينة حالياً. اطلب من المدير تعيين سائقين لهذه المنطقة.';

  @override
  String get openChat => 'محادثة';

  @override
  String get supportTitle => 'الدعم';

  @override
  String get contactManagement => 'التواصل مع الإدارة';

  @override
  String get supportMessageHint => 'صف مشكلتك أو سؤالك…';

  @override
  String get supportSent => 'تم إرسال الرسالة إلى الإدارة.';

  @override
  String get callSupport => 'اتصال';

  @override
  String get whatsappSupport => 'دعم واتساب';

  @override
  String get emailSupport => 'دعم البريد الإلكتروني';

  @override
  String get legalDocuments => 'الشروط والخصوصية';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsOfService => 'شروط الخدمة';

  @override
  String get managementReply => 'الإدارة';

  @override
  String get supportInboxTab => 'صندوق الدعم';

  @override
  String get noSupportMessages => 'لا توجد رسائل دعم بعد.';

  @override
  String get replyToUser => 'رد على المستخدم…';

  @override
  String get closeThread => 'إغلاق';

  @override
  String get driverHistoryTitle => 'سجل السائق';

  @override
  String get viewDriverHistory => 'عرض سجل الرحلات';

  @override
  String get earningsTab => 'الأرباح';

  @override
  String get commissionSettingsTitle => 'عمولة المنصة';

  @override
  String get commissionSettingsHint =>
      'حدد النسبة التي تحتفظ بها المنصة من أجرة كل رحلة مكتملة. تنطبق على جميع السائقين.';

  @override
  String get platformPercentLabel => 'نسبة العمولة';

  @override
  String get saveCommissionSettings => 'حفظ العمولة';

  @override
  String get commissionSaved => 'تم حفظ إعدادات العمولة.';

  @override
  String get commissionSaveFailed =>
      'تعذّر حفظ العمولة. أدخل قيمة بين 0 و 100.';

  @override
  String get totalPlatformProfit => 'إجمالي أرباح المنصة';

  @override
  String get managerProfitByDriver => 'الربح حسب السائق';

  @override
  String get managerProfitFromDriver => 'ربحك';

  @override
  String get driverNetEarnings => 'أرباح السائق';

  @override
  String get platformCommission => 'عمولة المنصة';

  @override
  String get outstandingProfitLabel => 'الربح المستحق';

  @override
  String get outstandingProfitTotal => 'إجمالي الربح المستحق';

  @override
  String get lifetimeProfitLabel => 'الربح التراكمي';

  @override
  String get lifetimeProfitTotal => 'إجمالي الربح التراكمي';

  @override
  String get owedToPlatformLabel => 'المبلغ المستحق للمنصة';

  @override
  String get lastProfitReceivedLabel => 'آخر استلام للأرباح';

  @override
  String get receivedProfitsTitle => 'تأكيد استلام الأرباح';

  @override
  String get receivedProfitsAction => 'تم استلام الأرباح';

  @override
  String receivedProfitsConfirm(String amount) {
    return 'تأكيد استلام $amount من هذا السائق. سيتم تصفير الرصيد المستحق للرحلات القادمة.';
  }

  @override
  String get receivedProfitsSuccess =>
      'تم استلام الأرباح وتصفير الرصيد المستحق.';

  @override
  String get driverBonusesTab => 'المكافآت';

  @override
  String get driverBonusesHint =>
      'منح مكافآت للسائقين وتعليمها كمدفوعة عند الصرف.';

  @override
  String get grantBonusQuickTitle => 'منح مكافأة لسائق';

  @override
  String get grantBonusTitle => 'منح مكافأة';

  @override
  String grantBonusHint(String driverName) {
    return 'إضافة مكافأة لـ $driverName.';
  }

  @override
  String get grantBonusAction => 'منح مكافأة';

  @override
  String get bonusAmountLabel => 'مبلغ المكافأة';

  @override
  String get bonusReasonLabel => 'السبب (اختياري)';

  @override
  String get bonusAmountInvalid => 'أدخل مبلغ مكافأة صحيح.';

  @override
  String get bonusGranted => 'تم منح المكافأة.';

  @override
  String get pendingBonusLabel => 'مكافأة معلقة';

  @override
  String get pendingBonusesTitle => 'المكافآت المعلقة';

  @override
  String get noPendingBonuses => 'لا توجد مكافآت معلقة.';

  @override
  String get markBonusPaid => 'تم الدفع';

  @override
  String get bonusMarkedPaid => 'تم تعليم المكافأة كمدفوعة.';

  @override
  String get completedRidesCount => 'الرحلات المكتملة';

  @override
  String get yourEarningsTitle => 'أرباحك';

  @override
  String rideEarningsManager(String fare, String profit, String percent) {
    return 'الأجرة $fare • ربحك $profit ($percent%)';
  }

  @override
  String rideEarningsDriver(String net, String fee, String percent) {
    return 'تستلم $net • عمولة المنصة $fee ($percent%)';
  }

  @override
  String get idPhotoLabel => 'صورة الهوية';

  @override
  String get profilePhotoLabel => 'صورة الملف الشخصي';

  @override
  String get pickFromGallery => 'المعرض';

  @override
  String get takePhoto => 'الكاميرا';

  @override
  String get driverTermsTitle => 'شروط العمل مع Hello Tuk-Tuk';

  @override
  String get driverTermsBody =>
      'توافق على الالتزام بقواعد التطبيق، وتقديم رحلات آمنة، وتحصيل الأجرة نقداً بأمانة، وقبول مراجعة الإدارة لوثائقك وحظر حسابك عند الإلغاءات المتكررة أو المخالفات.';

  @override
  String get acceptDriverTerms => 'أوافق على الشروط للعمل مع هذا التطبيق';

  @override
  String get registrationFieldsRequired => 'يرجى تعبئة الحقول المطلوبة.';

  @override
  String get vehiclePlateOptional => 'رقم اللوحة (اختياري)';

  @override
  String get licenseNumberOptional => 'رقم الرخصة (اختياري)';

  @override
  String get registrationPhotosRequired =>
      'يرجى رفع صورة الهوية وصورتك الشخصية.';

  @override
  String get registrationTermsRequired =>
      'يجب الموافقة على الشروط قبل الإرسال.';

  @override
  String get registrationSubmitFailed =>
      'تعذّر إرسال التسجيل. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get photoPickFailed =>
      'تعذّر تحميل الصورة. اسمح بالكاميرا أو المعرض وحاول مرة أخرى.';

  @override
  String get registrationStorageRulesHint =>
      'Firebase منع رفع الصور. افتح Firebase Console → Storage → Rules، الصق storage.rules من المشروع، ثم Publish.';

  @override
  String get customersTab => 'الزبائن';

  @override
  String get noCustomers => 'لا يوجد زبائن بعد.';

  @override
  String get blockUser => 'حظر';

  @override
  String get unblockUser => 'إلغاء الحظر';

  @override
  String get removeDriver => 'حذف الحساب';

  @override
  String get removeDriverConfirmTitle => 'حذف حساب هذا السائق؟';

  @override
  String get removeDriverConfirmMessage =>
      'سيتم حذف ملفهم من التطبيق. يمكنهم استخدام نسيت كلمة المرور ثم تسجيل الدخول بنفس الهاتف للبدء من جديد.';

  @override
  String get driverRemoved => 'تم حذف حساب السائق.';

  @override
  String get removeDriverFailed => 'تعذر حذف حساب السائق. حاول مرة أخرى.';

  @override
  String get deleteCustomer => 'حذف الحساب';

  @override
  String get removeCustomerConfirmTitle => 'حذف حساب هذا الزبون؟';

  @override
  String get removeCustomerConfirmMessage =>
      'سيتم حذف ملفهم من التطبيق. يمكنهم استخدام نسيت كلمة المرور ثم تسجيل الدخول بنفس الهاتف للبدء من جديد.';

  @override
  String get customerRemoved => 'تم حذف حساب الزبون.';

  @override
  String get removeCustomerFailed => 'تعذر حذف حساب الزبون. حاول مرة أخرى.';

  @override
  String get accountReleasedSignupHint =>
      'تمت إعادة تعيين هذا الرقم من قبل المدير. استخدم نسيت كلمة المرور لتعيين كلمة جديدة، ثم سجّل الدخول لإنشاء ملفك من جديد.';

  @override
  String get blockedLabel => 'محظور';

  @override
  String get accountBlockedTitle => 'الحساب محظور';

  @override
  String get driverBlockedBody =>
      'تم حظر حسابك كسائق من قبل الإدارة. تواصل مع الدعم إذا كان ذلك خطأ.';

  @override
  String get customerBlockedBody =>
      'تم حظر حسابك بسبب إلغاء رحلات متكررة أو مخالفات أخرى. تواصل مع الدعم للمساعدة.';

  @override
  String get cancelledRidesCount => 'الرحلات الملغاة';

  @override
  String get noDriverPhotos => 'لم يتم رفع صور.';

  @override
  String get addBracket => 'إضافة شريحة';

  @override
  String get removeBracket => 'حذف الشريحة';

  @override
  String get liveMapTab => 'الخريطة الحية';

  @override
  String get tripDetailsTitle => 'تفاصيل الرحلة';

  @override
  String get customerDetails => 'الزبون';

  @override
  String get driverDetails => 'السائق';

  @override
  String get noDriverAssigned => 'لم يُعيَّن سائق بعد.';

  @override
  String get managerProfileTitle => 'ملف المدير';

  @override
  String get noLocationYet => 'الموقع غير متوفر';

  @override
  String get noOnlineDrivers => 'لا يوجد سائقون متصلون الآن.';

  @override
  String get tripMapTitle => 'خريطة الرحلة';

  @override
  String get tripStatusLabel => 'حالة الرحلة';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get myProfileTitle => 'ملفي';

  @override
  String get myTripsTitle => 'رحلاتي';

  @override
  String get accountInformation => 'معلومات الحساب';

  @override
  String get accountTypeLabel => 'نوع الحساب';

  @override
  String get registeredAt => 'تاريخ التسجيل';

  @override
  String get tripDateTime => 'التاريخ والوقت';

  @override
  String get tripHistoryHint => 'رحلاتك المكتملة والملغاة مع التاريخ والوقت.';

  @override
  String totalTripsCount(int count) {
    return '$count رحلة مكتملة';
  }

  @override
  String get rateDriverTitle => 'قيّم السائق';

  @override
  String get rateDriverHint => 'كيف كانت رحلتك؟';

  @override
  String get driverFeedbackLabel => 'ملاحظات (اختياري)';

  @override
  String get driverFeedbackHint => 'شاركنا تجربتك مع السائق';

  @override
  String get submitRating => 'إرسال التقييم';

  @override
  String get ratingSubmitted => 'شكراً لملاحظاتك!';

  @override
  String get driverReviewsTab => 'تقييمات السائقين';

  @override
  String get noDriverReviews => 'لا توجد تقييمات بعد';

  @override
  String get driverLabel => 'السائق';

  @override
  String get customerLabel => 'الزبون';

  @override
  String get unknownUser => 'غير معروف';

  @override
  String get feedbackLabel => 'الملاحظات';

  @override
  String get awaitingPayment => 'بانتظار تأكيد الدفع';

  @override
  String get cityPricingLabel => 'المدينة / القضاء';

  @override
  String get roleAssistant => 'مساعد';

  @override
  String get assistantsTab => 'المساعدون';

  @override
  String get assistantsTabHint => 'أنشئ حسابات للفريق مع صلاحيات محدودة.';

  @override
  String get createAssistantTitle => 'حساب مساعد جديد';

  @override
  String get createAssistantButton => 'إنشاء مساعد';

  @override
  String get assistantPermissionsTitle => 'الصلاحيات المسموحة';

  @override
  String get assistantFormInvalid =>
      'أدخل الاسم وبريداً صحيحاً وكلمة مرور (6 أحرف على الأقل).';

  @override
  String get assistantCreated => 'تم إنشاء حساب المساعد.';

  @override
  String get assistantCreateFailed => 'تعذر إنشاء المساعد.';

  @override
  String get existingAssistantsTitle => 'أعضاء الفريق';

  @override
  String get noAssistantsYet => 'لا يوجد مساعدون بعد.';

  @override
  String get editAssistantPermissions => 'تعديل الصلاحيات';

  @override
  String get assistantLoginHint =>
      'استخدم البريد وكلمة المرور التي أعطاك إياها الإدارة.';

  @override
  String get assistantNoPermissions =>
      'حسابك لا يملك صلاحيات. تواصل مع المدير.';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get permPendingDrivers => 'الموافقة على السائقين المعلقين';

  @override
  String get permActiveRides => 'عرض الرحلات النشطة';

  @override
  String get permLiveMap => 'عرض الخريطة الحية';

  @override
  String get permAllDrivers => 'عرض كل السائقين';

  @override
  String get permCustomers => 'إدارة الزبائن';

  @override
  String get permRideHistory => 'عرض سجل الرحلات';

  @override
  String get permPricing => 'تعديل أسعار المدينة';

  @override
  String get permEarnings => 'عرض الأرباح والعمولة';

  @override
  String get permDriverReviews => 'عرض تقييمات السائقين';

  @override
  String get permSupportInbox => 'صندوق الدعم';

  @override
  String get permManageAssistants => 'إدارة المساعدين';

  @override
  String get filterByCity => 'تصفية حسب المدينة';

  @override
  String get allCities => 'كل المدن';

  @override
  String get filterBySubDistrict => 'تصفية حسب الناحية';

  @override
  String get allSubDistricts => 'كل النواحي';

  @override
  String get filterByMonth => 'تصفية حسب الشهر';

  @override
  String get allMonths => 'كل الأشهر';

  @override
  String tripsInMonth(int count) {
    return '$count رحلة';
  }

  @override
  String get supportContactSettings => 'رقم الدعم';

  @override
  String get supportPhoneLabel => 'رقم هاتف الدعم';

  @override
  String get supportWhatsappLabel => 'رقم واتساب';

  @override
  String get supportEmailLabel => 'البريد الإلكتروني للدعم';

  @override
  String get saveSupportContact => 'حفظ رقم الدعم';

  @override
  String get supportContactSaved => 'تم حفظ رقم الدعم.';

  @override
  String get pricingUsingDefaultsHint =>
      'يتم عرض الأسعار الافتراضية لهذه المدينة. عدّل القيم أدناه ثم اضغط حفظ لتخزينها في Firebase.';

  @override
  String pricingForCity(String city) {
    return 'أسعار $city';
  }

  @override
  String get pricingDistrictDefault => 'افتراضي القضاء (كل النواحي)';

  @override
  String pricingForArea(String district, String subDistrict) {
    return 'أسعار $district — $subDistrict';
  }

  @override
  String get pricingSubDistrictFallbackHint =>
      'إذا لم تُحفظ أسعار الناحية، تُستخدم أسعار القضاء الافتراضية للرحلات.';

  @override
  String get promoCodesTab => 'أكواد الخصم';

  @override
  String get promoCodesHint =>
      'يحصل الزبائن الجدد تلقائياً على كود FREE3 عند تفعيل الإسناد التلقائي.';

  @override
  String get promoCodeLabel => 'كود الخصم';

  @override
  String get promoCodeActive => 'مفعّل';

  @override
  String get promoEnabledLabel => 'تفعيل الكود';

  @override
  String get promoEnabledHint => 'أوقف الخصم دون حذف الكود.';

  @override
  String get promoAutoAssignLabel => 'إسناد تلقائي عند التسجيل';

  @override
  String get promoAutoAssignHint => 'منح هذا الكود لكل زبون جديد.';

  @override
  String get promoDiscountPercentLabel => 'نسبة الخصم';

  @override
  String get promoMaxDiscountLabel => 'أقصى خصم لكل رحلة';

  @override
  String get promoMaxRidesLabel => 'عدد الرحلات المخفّضة لكل زبون';

  @override
  String get promoDescriptionLabel => 'الوصف';

  @override
  String get savePromoCode => 'حفظ كود الخصم';

  @override
  String get promoCodeSaved => 'تم حفظ كود الخصم.';

  @override
  String promoDiscountApplied(String code, String amount) {
    return '$code: توفر $amount';
  }

  @override
  String get monthlyLeaderboardTab => 'لوحة الجائزة الشهرية';

  @override
  String monthlyLeaderboardMonth(String monthKey) {
    return 'الشهر: $monthKey';
  }

  @override
  String monthlyPrizeAmount(String amount) {
    return 'الجائزة: $amount';
  }

  @override
  String leaderboardRideCount(int count) {
    return '$count رحلة هذا الشهر';
  }

  @override
  String get leaderboardEmpty => 'لا توجد رحلات مكتملة هذا الشهر بعد.';

  @override
  String get markAsWinner => 'تحديد الفائز';

  @override
  String get markAsPaid => 'تم الدفع';

  @override
  String get resetMonthlyCounter => 'إعادة ضبط العداد الشهري';

  @override
  String get resetMonthlyConfirm =>
      'إعادة ضبط عدد رحلات كل السائقين للشهر الجديد؟ سيتم مسح الفائز الحالي.';

  @override
  String get leaderboardWinnerMarked => 'تم تحديد الفائز.';

  @override
  String get leaderboardPaidMarked => 'تم تسجيل دفع الجائزة.';

  @override
  String get leaderboardResetDone => 'تم إعادة ضبط العدادات الشهرية.';

  @override
  String get leaderboardWinnerBadge => 'فائز';

  @override
  String get leaderboardPaidBadge => 'مدفوع';

  @override
  String leaderboardCurrentWinner(String name) {
    return 'الفائز الحالي: $name';
  }

  @override
  String get permPromoCodes => 'إدارة أكواد الخصم';

  @override
  String get permMonthlyLeaderboard => 'لوحة الجائزة الشهرية';

  @override
  String get driverMonthlyPrizeTitle => 'تحدي الجائزة الشهرية';

  @override
  String driverMonthlyRideCount(int count) {
    return '$count رحلة هذا الشهر';
  }

  @override
  String driverMonthlyRank(int rank, int count) {
    return 'أنت #$rank هذا الشهر — $count رحلة';
  }

  @override
  String driverMonthlyPrizeAmount(String amount) {
    return 'أفضل سائق هذا الشهر يفوز بـ $amount!';
  }

  @override
  String get ridePromoSectionTitle => 'تم استخدام كود خصم';

  @override
  String ridePromoCodeUsed(String code) {
    return 'الكود: $code';
  }

  @override
  String ridePromoOriginalFare(String amount) {
    return 'الأجرة الكاملة: $amount';
  }

  @override
  String ridePromoCustomerPaid(String amount) {
    return 'دفع الزبون: $amount';
  }

  @override
  String ridePromoDiscountAmount(String amount) {
    return 'قيمة الخصم: $amount';
  }

  @override
  String rideDriverCompensationOwed(String amount) {
    return 'ادفع للسائق: $amount';
  }

  @override
  String get rideDriverCompensationHint =>
      'الزبون دفع أقل بسبب الخصم. ادفع للسائق هذا المبلغ حتى لا يتضرر.';

  @override
  String ridePromoUsedCompact(String code, String amount) {
    return '$code −$amount';
  }

  @override
  String rideDriverCompensationCompact(String amount) {
    return 'ادفع للسائق $amount';
  }

  @override
  String get fakeDriversTitle => 'سائقون تجريبيون';

  @override
  String get fakeDriversHint =>
      'أنشئ سائقاً وهمياً للاختبار. عند تفعيله يظهر متصلاً في الحلة ويقبل الرحلات تلقائياً.';

  @override
  String get createFakeDriver => 'إنشاء سائق تجريبي';

  @override
  String get fakeDriverCreated =>
      'تم إنشاء السائق التجريبي. اضغط تفعيل للاتصال.';

  @override
  String get fakeDriverBadge => 'تجريبي';

  @override
  String get activateFakeDriver => 'تفعيل';

  @override
  String get deactivateFakeDriver => 'إيقاف';

  @override
  String get fakeDriverActivated =>
      'السائق التجريبي متصل وسيقبل الرحلات تلقائياً.';

  @override
  String get fakeDriverDeactivated => 'السائق التجريبي غير متصل.';

  @override
  String get driverNameLabel => 'اسم السائق';

  @override
  String get savedPlacesTitle => 'الأماكن المحفوظة';

  @override
  String get placeSaveAction => 'حفظ المكان';

  @override
  String get placeRemoveFromSaved => 'إزالة من المحفوظات';

  @override
  String get placeSaved => 'تم حفظ المكان.';

  @override
  String get placeRemovedFromSaved => 'تمت الإزالة من الأماكن المحفوظة.';

  @override
  String get savedPlacesEmptyHint => 'ابحث عن مكان واضغط حفظ ليظهر هنا.';

  @override
  String get savePlaceShort => 'حفظ';

  @override
  String get savedPlaceShort => 'محفوظ';

  @override
  String get savePlaceHint =>
      'اضغط حفظ بجانب أي نتيجة لإضافتها إلى أماكنك المحفوظة.';

  @override
  String get broadcastToDrivers => 'رسالة لجميع السائقين';

  @override
  String get broadcastToCustomers => 'رسالة لجميع الزبائن';

  @override
  String get broadcastDriversHint => 'إرسال إشعار push لكل سائق معتمد.';

  @override
  String get broadcastCustomersHint => 'إرسال إشعار push لكل زبون.';

  @override
  String get announcementTitleLabel => 'العنوان';

  @override
  String get announcementMessageLabel => 'الرسالة';

  @override
  String get announcementDefaultTitle => 'إعلان';

  @override
  String get announcementFieldsRequired => 'أدخل العنوان والرسالة.';

  @override
  String get sendAnnouncement => 'إرسال';

  @override
  String broadcastSentSummary(int sent, int total) {
    return 'تم الإرسال إلى $sent من $total جهاز.';
  }

  @override
  String broadcastPublishedSummary(int total) {
    return 'تم نشر الإعلان لـ $total مستخدم. سيصلهم داخل التطبيق.';
  }

  @override
  String get broadcastSendFailed =>
      'تعذر إرسال الإعلان. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get editProfileTitle => 'تعديل الملف الشخصي';

  @override
  String get editProfileButton => 'تعديل الملف';

  @override
  String get saveProfile => 'حفظ الملف';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي.';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPassword => 'تأكيد كلمة المرور الجديدة';

  @override
  String get changePasswordButton => 'تحديث كلمة المرور';

  @override
  String get passwordChanged => 'تم تحديث كلمة المرور.';

  @override
  String get passwordFieldsRequired => 'أدخل كلمة المرور الحالية والجديدة.';

  @override
  String get passwordsDoNotMatch => 'كلمتا المرور الجديدتان غير متطابقتين.';

  @override
  String get fullNameRequired => 'الاسم مطلوب.';

  @override
  String get phoneChangeHint =>
      'لتغيير رقم الهاتف، أدخل الرقم الجديد وكلمة المرور الحالية أدناه.';

  @override
  String get currentPasswordForPhoneChange =>
      'كلمة المرور الحالية (مطلوبة لتغيير الهاتف)';

  @override
  String get phoneChangePasswordRequired =>
      'أدخل كلمة المرور الحالية لتغيير رقم الهاتف.';

  @override
  String get recoveryEmailLabel => 'البريد الاختياري للاستعادة';

  @override
  String get recoveryEmailHint => 'بريد اختياري لاستعادة الحساب.';

  @override
  String get forgotPasswordStepsHint => 'أدخل رقم هاتفك وكلمة المرور الجديدة.';

  @override
  String get whatsappOtpTitle => 'التحقق عبر الرسائل النصية';

  @override
  String get whatsappOtpInstructions =>
      'أدخل رمز التحقق المكوّن من 6 أرقام الذي أرسلناه برسالة نصية.';

  @override
  String whatsappOtpSent(String phone) {
    return 'تم إرسال رمز التحقق إلى $phone.';
  }

  @override
  String get whatsappOtpResend => 'إعادة إرسال الرمز';

  @override
  String whatsappOtpResendWait(int seconds) {
    return 'إعادة الإرسال خلال $seconds ث';
  }

  @override
  String get whatsappOtpSendFailed =>
      'تعذّر إرسال رمز التحقق عبر الرسائل النصية. حاول مرة أخرى.';

  @override
  String get whatsappOtpIncorrect => 'رمز التحقق غير صحيح.';

  @override
  String get whatsappOtpExpired =>
      'انتهت صلاحية رمز التحقق. اضغط إعادة إرسال الرمز وحاول مرة أخرى.';

  @override
  String get whatsappOtpTooManyAttempts => 'محاولات كثيرة. اطلب رمزاً جديداً.';

  @override
  String get whatsappOtpSignupHint =>
      'سنرسل رمز تحقق عبر رسالة نصية قبل إنشاء حسابك.';

  @override
  String get openPasswordResetPage => 'فتح صفحة إعادة التعيين';

  @override
  String get resetLinkOpened =>
      'تم فتح صفحة إعادة تعيين كلمة المرور. عيّن كلمة مرورك الجديدة هناك.';

  @override
  String get resetWhileLoggedInHint =>
      'إذا كنت مسجلاً الدخول، افتح الملف الشخصي → تعديل الملف → تغيير كلمة المرور.';

  @override
  String get announcementsTitle => 'الإعلانات';

  @override
  String get announcementsEmpty => 'لا توجد إعلانات من المدير بعد.';
}
