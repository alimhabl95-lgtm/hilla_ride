enum AppVariant {
  mobile,
  admin,
}

extension AppVariantX on AppVariant {
  String get appTitle => switch (this) {
        AppVariant.mobile => 'Hello Tuk-Tuk',
        AppVariant.admin => 'Hello Tuk-Tuk Admin',
      };

  bool get isWebAdmin => this == AppVariant.admin;
}

class AppConfig {
  AppConfig._();

  static AppVariant variant = AppVariant.mobile;
}
