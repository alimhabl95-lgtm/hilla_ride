import 'dart:async';
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';

class AnimatedMapMarker {
  AnimatedMapMarker({
    required this.id,
    required this.position,
    required this.heading,
  });

  final String id;
  LatLng position;
  double heading;
  LatLng? _from;
  LatLng? _to;
  double _fromHeading = 0;
  double _toHeading = 0;
  double _t = 1;

  void target(LatLng next, double nextHeading) {
    _from = position;
    _to = next;
    _fromHeading = heading;
    _toHeading = nextHeading;
    _t = 0;
  }

  bool tick(double dtSeconds, Duration duration) {
    if (_to == null || _t >= 1) return false;
    _t = math.min(1, _t + dtSeconds / (duration.inMilliseconds / 1000));
    final eased = _easeOutCubic(_t);
    final from = _from!;
    final to = _to!;
    position = LatLng(
      from.latitude + (to.latitude - from.latitude) * eased,
      from.longitude + (to.longitude - from.longitude) * eased,
    );
    heading = _lerpHeading(_fromHeading, _toHeading, eased);
    if (_t >= 1) {
      position = to;
      heading = _toHeading;
      _to = null;
    }
    return true;
  }

  static double _easeOutCubic(double t) {
    final u = 1 - t;
    return 1 - u * u * u;
  }

  static double _lerpHeading(double a, double b, double t) {
    var delta = (b - a) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return (a + delta * t) % 360;
  }
}

/// Owns animated driver marker positions for Google Maps.
class MarkerAnimator {
  MarkerAnimator({
    this.duration = MapPresenceConfig.markerAnimationDuration,
  });

  final Duration duration;
  final Map<String, AnimatedMapMarker> _markers = {};
  Timer? _timer;
  void Function()? onTick;

  Map<String, AnimatedMapMarker> get markers => _markers;

  void start() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 32), (_) {
      var changed = false;
      for (final marker in _markers.values) {
        if (marker.tick(0.032, duration)) changed = true;
      }
      if (changed) onTick?.call();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _markers.clear();
  }

  void syncTargets(Map<String, ({LatLng position, double heading})> targets) {
    start();
    final keep = targets.keys.toSet();
    _markers.removeWhere((id, _) => !keep.contains(id));
    targets.forEach((id, value) {
      final existing = _markers[id];
      if (existing == null) {
        _markers[id] = AnimatedMapMarker(
          id: id,
          position: value.position,
          heading: value.heading,
        );
      } else {
        final moved = _distanceMeters(existing.position, value.position) > 0.5;
        final turned = ((existing.heading - value.heading).abs() % 360) > 2;
        if (moved || turned) {
          existing.target(value.position, value.heading);
        }
      }
    });
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earth * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
