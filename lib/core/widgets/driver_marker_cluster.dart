import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/widgets/marker_animator.dart';

/// Lightweight clustering for overlapping available-driver markers.
///
/// When many available tuk-tuks sit within [mergeMeters], they collapse to one
/// marker (same official icon, no count labels). At higher zoom, markers expand.
class DriverMarkerCluster {
  DriverMarkerCluster._();

  static List<AnimatedMapMarker> apply(
    Iterable<AnimatedMapMarker> markers, {
    required double zoom,
    double mergeMeters = 45,
  }) {
    final list = markers.toList(growable: false);
    if (list.length < 3) return list;
    // Only cluster when zoomed out enough that icons overlap.
    if (zoom >= 15.5) return list;

    final cellMeters = zoom >= 14.5 ? mergeMeters : mergeMeters * 1.8;
    final used = <int>{};
    final out = <AnimatedMapMarker>[];

    for (var i = 0; i < list.length; i++) {
      if (used.contains(i)) continue;
      final a = list[i];
      var latSum = a.position.latitude;
      var lngSum = a.position.longitude;
      var heading = a.heading;
      var count = 1;
      used.add(i);

      for (var j = i + 1; j < list.length; j++) {
        if (used.contains(j)) continue;
        final b = list[j];
        if (_meters(a.position, b.position) <= cellMeters) {
          used.add(j);
          latSum += b.position.latitude;
          lngSum += b.position.longitude;
          heading = b.heading;
          count++;
        }
      }

      out.add(
        AnimatedMapMarker(
          id: count == 1 ? a.id : 'cluster_${a.id}_$count',
          position: LatLng(latSum / count, lngSum / count),
          heading: heading,
        ),
      );
    }
    return out;
  }

  static double _meters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earth * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
