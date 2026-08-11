/// Google Maps + Places API keys for **Hello tiktok** (`hello-tiktok-57dc5`).
///
/// Manage keys: https://console.cloud.google.com/apis/credentials?project=hello-tiktok-57dc5
///
/// ## iOS key (Firebase) — map tiles on iPhone
/// `AIzaSyDD4…` → native iOS `GMSApiKey` / `MapsConfig.mapRenderKey`
/// Application restrictions: **iOS apps** → `com.hillaride.hillaRide`
/// APIs: **Maps SDK for iOS** (+ Places/Directions if needed)
///
/// ## Android key (Firebase) — map tiles on Android
/// [androidMapApiKey] → `android/app/src/main/AndroidManifest.xml`
/// Application restrictions: **Android apps** → package `com.hillaride.hilla_ride` + SHA-1
/// APIs: **Maps SDK for Android**, Places API (New) recommended
///
/// ## Browser key (Firebase) — place search HTTP + web map
/// [placesWebApiKey] → [GooglePlacesService] / `web/index.html`
/// Application restrictions: **None** (or HTTP referrers for hosting domains)
/// APIs required: **Places API (New)**, **Maps JavaScript API**
/// Optional: Geocoding API, Directions API
class MapsConfig {
  MapsConfig._();

  /// Firebase Android key — map widget on Android.
  static const String androidMapApiKey =
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
