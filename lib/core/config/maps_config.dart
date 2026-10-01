/// Google Maps + Places API keys for **Hello tiktok** (`hello-tiktok-57dc5`).
///
/// Manage keys: https://console.cloud.google.com/apis/credentials?project=hello-tiktok-57dc5
///
/// ## iOS key (Firebase) — map tiles on iPhone only
/// `AIzaSyDD4…` → native iOS `GMSApiKey` / `MapsConfig.mapRenderKey`
/// Application restrictions: **iOS apps** → `com.hillaride.hillaRide`
/// APIs: **Maps SDK for iOS** only is OK for this key
/// Do NOT use this Maps-only key in GoogleService-Info.plist (breaks login).
///
/// ## Android map tiles
/// Android ride maps use the Maps JavaScript API inside a WebView with
/// [placesWebApiKey] (same as `web/index.html`). Native Maps SDK for Android
/// tiles stay unused so iOS is unchanged and no Cloud key edits are required.
///
/// Dedicated Android-restricted key (optional later):
/// `AIzaSyATkDQ-s_PdP3rbRnrvkLs4XXrIAdzE7Q0`
/// Package: `com.hillaride.hilla_ride`
/// Release upload keystore SHA-1:
/// `40:52:5A:F2:4D:47:91:88:CF:CD:B2:6A:46:35:67:97:03:59:CB:23`
///
/// ## Browser key (Firebase) — Auth + place search HTTP + web map + Android tiles
/// [placesWebApiKey] → GoogleService-Info / google-services.json / Places / `web/index.html`
/// Application restrictions: **None** (or HTTP referrers for hosting domains)
/// APIs required: **Identity Toolkit**, **Places API (New)**, **Maps JavaScript API**,
/// **Maps SDK for Android** (needed for native Android road tiles)
class MapsConfig {
  MapsConfig._();

  /// Android map tiles use the default NORMAL Google Maps style (no Map ID,
  /// no JSON style). The Browser key must allow **Maps SDK for Android**.
  static const String androidMapApiKey = placesWebApiKeyEmbedded;

  /// Optional Android-apps-restricted Maps key (requires matching SHA-1).
  static const String androidRestrictedMapApiKey =
      'AIzaSyATkDQ-s_PdP3rbRnrvkLs4XXrIAdzE7Q0';

  /// Firebase Browser key — Places Text Search + web Maps JS.
  static const String placesWebApiKeyEmbedded =
      'AIzaSyAsgktwgQMXi9i5majam_z3Yion1_0qqLY';

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: androidMapApiKey,
  );

  /// HTTP Places/Geocoding key. Override with --dart-define=GOOGLE_PLACES_WEB_API_KEY=...
  static String get placesWebApiKey {
    const fromEnv = String.fromEnvironment('GOOGLE_PLACES_WEB_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return placesWebApiKeyEmbedded;
  }

  static bool get useGooglePlacesHttp =>
      placesWebApiKey.isNotEmpty &&
      placesWebApiKey != 'YOUR_GOOGLE_MAPS_API_KEY';

  static bool get isConfigured =>
      googleMapsApiKey.isNotEmpty &&
      googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY';
}
