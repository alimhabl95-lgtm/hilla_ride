import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Minimal description of a neighboring service area, used only for the
/// nearest-center tie-break in [GeoPolygon.isWithinBoundaryUnique].
class GeoArea {
  const GeoArea({
    required this.center,
    required this.radiusKm,
    this.boundary,
  });

  final LatLng center;
  final double radiusKm;
  final List<LatLng>? boundary;
}

/// Shared polygon geometry helpers so iOS, Android/Flutter, and Cloud
/// Functions treat the same stored (or synthesized) boundary identically.
class GeoPolygon {
  GeoPolygon._();

  static const double _earthRadiusKm = 6371.0;

  /// Ray-casting point-in-polygon test. [polygon] is an open ring (first
  /// point not repeated at the end). Works directly on lat/lng degrees,
  /// which is an acceptable approximation for the small (sub-district
  /// sized) areas this app operates on.
  static bool pointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    var inside = false;
    final x = point.longitude;
    final y = point.latitude;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersects =
          (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi;
      if (intersects) inside = !inside;
      j = i;
    }
    return inside;
  }

  /// Builds a regular [sides]-gon polygon approximating a circle of
  /// [radiusKm] centered at [center]. Used as a temporary boundary for
  /// sub-districts that don't yet have an Admin-drawn polygon.
  static List<LatLng> syntheticPolygonFromCircle(
    LatLng center,
    double radiusKm, {
    int sides = 16,
  }) {
    final points = <LatLng>[];
    for (var i = 0; i < sides; i++) {
      final bearingDeg = (360.0 / sides) * i;
      points.add(_destinationPoint(center, radiusKm, bearingDeg));
    }
    return points;
  }

  /// Maximum distance (km) from [center] to any vertex of [polygon].
  /// Used to size a Google Places location bias so it covers the whole
  /// effective boundary, not just the raw stored radius.
  static double boundingRadiusKm(LatLng center, List<LatLng> polygon) {
    if (polygon.isEmpty) return 0;
    var maxKm = 0.0;
    for (final p in polygon) {
      final km = _distanceKm(center, p);
      if (km > maxKm) maxKm = km;
    }
    return maxKm;
  }

  /// Resolves the effective boundary for an area: the stored polygon when
  /// present (>= 3 points), otherwise a synthesized polygon from
  /// center + radius. This is the single place that decides "real polygon
  /// vs. temporary circle-derived polygon" — every call site upgrades
  /// automatically the moment Admin draws a real boundary.
  static List<LatLng> effectiveBoundary({
    required LatLng center,
    required double radiusKm,
    List<LatLng>? storedBoundary,
  }) {
    if (storedBoundary != null && storedBoundary.length >= 3) {
      return storedBoundary;
    }
    return syntheticPolygonFromCircle(center, radiusKm);
  }

  /// True when [point] falls inside the effective boundary of an area
  /// described by [center] + [radiusKm] (+ optional [storedBoundary]).
  static bool isWithinBoundary({
    required LatLng point,
    required LatLng center,
    required double radiusKm,
    List<LatLng>? storedBoundary,
  }) {
    final boundary = effectiveBoundary(
      center: center,
      radiusKm: radiusKm,
      storedBoundary: storedBoundary,
    );
    return pointInPolygon(point, boundary);
  }

  /// True when [point] belongs to this area specifically, resolving the
  /// ambiguity that arises when two *temporary* circle boundaries (no
  /// Admin-drawn polygon yet) overlap — e.g. Qasim and Al-Shumali are both
  /// large synthesized circles inside the same district. In that overlap
  /// case the point is assigned to whichever area's center is nearest, so
  /// a point clearly inside Qasim never also counts as "inside" Al-Shumali
  /// just because the circles overlap. An Admin-drawn polygon (on this
  /// area or a neighboring one) is always authoritative and skips the
  /// tie-break entirely.
  static bool isWithinBoundaryUnique({
    required LatLng point,
    required LatLng center,
    required double radiusKm,
    List<LatLng>? storedBoundary,
    List<GeoArea> others = const [],
  }) {
    final inside = isWithinBoundary(
      point: point,
      center: center,
      radiusKm: radiusKm,
      storedBoundary: storedBoundary,
    );
    if (!inside) return false;
    // A real drawn polygon on this area is authoritative — no tie-break.
    if (storedBoundary != null && storedBoundary.length >= 3) return true;

    final selfDistanceKm = _distanceKm(center, point);
    for (final other in others) {
      if (other.boundary != null && other.boundary!.length >= 3) {
        // A neighbor's real drawn polygon always wins over our synthetic
        // circle, since it's ground truth rather than an approximation.
        if (pointInPolygon(point, other.boundary!)) return false;
        continue;
      }
      final otherInside = isWithinBoundary(
        point: point,
        center: other.center,
        radiusKm: other.radiusKm,
      );
      if (!otherInside) continue;
      if (_distanceKm(other.center, point) < selfDistanceKm) return false;
    }
    return true;
  }

  static double _distanceKm(LatLng a, LatLng b) {
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLng * sinDLng;
    return _earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  static LatLng _destinationPoint(
    LatLng start,
    double distanceKm,
    double bearingDeg,
  ) {
    final d = distanceKm / _earthRadiusKm;
    final brng = _deg2rad(bearingDeg);
    final lat1 = _deg2rad(start.latitude);
    final lon1 = _deg2rad(start.longitude);

    final lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng));
    final lon2 = lon1 +
        atan2(
          sin(brng) * sin(d) * cos(lat1),
          cos(d) - sin(lat1) * sin(lat2),
        );
    return LatLng(_rad2deg(lat2), _rad2deg(lon2));
  }

  static double _deg2rad(double deg) => deg * pi / 180.0;
  static double _rad2deg(double rad) => rad * 180.0 / pi;
}
