/// Google Maps + Places + Geocoding API keys for **Hello tiktok**.
///
/// Google Cloud project with billing: **taxiapp2024** (console name: Hello tiktok).
/// Enable APIs: https://console.cloud.google.com/apis/library?project=taxiapp2024
/// Manage keys: https://console.cloud.google.com/apis/credentials?project=taxiapp2024
///
/// ## Key 1 — Map display (Android)
/// [androidMapApiKey] → `android/app/src/main/AndroidManifest.xml`
/// Restrictions: **Android apps** only
/// - Package: `com.hillaride.hilla_ride`
/// - SHA-1 (debug): `f9:1c:7e:b9:d2:d8:f3:36:a5:71:91:7d:88:d6:a1:8e:fa:e0:60:65`
/// APIs: Maps SDK for Android **and Places API (New)**
///
/// ## Key 2 — Place search + geocoding (HTTP from Flutter)
/// [placesWebApiKey] → used by [GooglePlacesService]
/// Restrictions: **Application restrictions = None** (or HTTP referrers below)
/// APIs: **Places API (New)** (required — legacy Places Text Search is disabled)
/// Geocoding API optional (reverse geocode falls back to OpenStreetMap)
///
/// ## Web hosting (iPhone Safari / Firebase Hosting)
/// The same key is loaded in `web/index.html` for the map widget.
/// In Google Cloud → Credentials → this key → add HTTP referrers:
/// - `https://hello-tiktok-57dc5.web.app/*`
/// - `https://hello-tiktok-57dc5.firebaseapp.com/*`
/// - `https://hello-tiktok-57dc5-admin.web.app/*`
/// - `http://localhost:*/*` (local testing)
/// Enable **Maps JavaScript API** for project taxiapp2024, then redeploy is not
/// required — refresh Safari after saving key changes (wait ~5 minutes).
///
/// On **web/Safari**, driving distance uses the Maps JavaScript Directions API
/// (same Google routing as Android). REST route APIs are not used in the browser.
class MapsConfig {
  MapsConfig._();

  /// Key 1 — map widget on Android (`AIzaSyBke…`).
  static const String androidMapApiKey =
      'AIzaSyBke5bjy0cHxAnYJ8x89WlvjECLOTcAbGE';

  /// Key 2 — Places Text/Nearby Search + Geocoding over HTTP (`AIzaSyCygb…`).
  static const String placesWebApiKeyEmbedded =
      'AIzaSyCygbeGlDUlA7l0GkJjB8TUHvHNUlHwsBg';

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
