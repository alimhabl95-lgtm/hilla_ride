/// Client surfaces that share one Firebase backend.
///
/// [business] powers today's Web Portal and the future Hello Tuk-Tuk Business
/// mobile app — same Auth accounts, Firestore collections, and callables.
enum AppVariant {
  mobile,
  admin,
  business,
}

extension AppVariantX on AppVariant {
  String get appTitle => switch (this) {
        AppVariant.mobile => 'Hello Tuk-Tuk',
        AppVariant.admin => 'Hello Tuk-Tuk Admin',
        AppVariant.business => 'Hello Tuk-Tuk Business',
      };

  bool get isWebAdmin => this == AppVariant.admin;
  bool get isWebBusiness => this == AppVariant.business;
  bool get isWebPortal => isWebAdmin || isWebBusiness;

  /// Same business client for web portal and future Play/App Store app.
  bool get isBusinessClient => this == AppVariant.business;
}

class AppConfig {
  AppConfig._();

  static AppVariant variant = AppVariant.mobile;
}
