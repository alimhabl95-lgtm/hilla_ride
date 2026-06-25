/// Public legal document URLs (Firebase Hosting).
class LegalConfig {
  LegalConfig._();

  static const String _host = 'https://hello-tiktok-57dc5.web.app';

  static String privacyPolicyUrl({String languageCode = 'en'}) =>
      '$_host/legal/privacy.html?lang=${languageCode == 'ar' ? 'ar' : 'en'}';

  static String termsOfServiceUrl({String languageCode = 'en'}) =>
      '$_host/legal/terms.html?lang=${languageCode == 'ar' ? 'ar' : 'en'}';
}
