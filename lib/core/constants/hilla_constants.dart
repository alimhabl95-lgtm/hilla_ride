import 'package:latlong2/latlong.dart';

/// Shared constants for the Hilla city ride service.
class HillaConstants {
  HillaConstants._();

  static const String appName = 'Hello Tuk-Tuk';
  static const String cityName = 'Hilla';
  static const String cityNameArabic = 'الحلة';
  static const String countryNameArabic = 'العراق';
  static const String cityCenterLabelArabic = 'مركز مدينة الحلة';

  /// City center — used as default map position.
  static const LatLng cityCenter = LatLng(32.4637, 44.4197);

  static const double defaultMapZoom = 14.0;
  static const double userLocationZoom = 16.0;

  /// Rough service area radius around city center (km).
  static const double serviceRadiusKm = 15.0;

  /// Nominatim search bounding box around Hilla (west,south,east,north).
  static const double searchBoundsWest = 44.30;
  static const double searchBoundsSouth = 32.40;
  static const double searchBoundsEast = 44.55;
  static const double searchBoundsNorth = 32.52;

  static const String defaultCountryCode = '+964';
}
