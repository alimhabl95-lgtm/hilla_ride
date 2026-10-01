import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class NavigationStep {
  const NavigationStep({
    required this.instruction,
    required this.maneuver,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.start,
    required this.end,
  });

  final String instruction;
  final String maneuver;
  final int distanceMeters;
  final int durationSeconds;
  final LatLng start;
  final LatLng end;
}

class TurnCue {
  const TurnCue({
    required this.instruction,
    required this.maneuver,
    required this.metersToManeuver,
    required this.remainingMeters,
    required this.remainingMinutes,
    required this.metersOffRoute,
    required this.offRoute,
  });

  final String instruction;
  final String maneuver;
  final int metersToManeuver;
  final int remainingMeters;
  final int remainingMinutes;
  final double metersOffRoute;
  final bool offRoute;
}

/// Matches live GPS to Directions steps and detects when to reroute.
class TurnByTurnGuide {
  TurnByTurnGuide._();

  static const double offRouteMeters = 55;
  static const double stepAdvanceMeters = 30;

  static TurnCue? evaluate({
    required List<NavigationStep> steps,
    required List<LatLng> polyline,
    required LatLng driver,
    required bool isEstimated,
  }) {
    if (steps.isEmpty && polyline.length < 2) return null;

    final off = polyline.length >= 2
        ? distanceToPolylineMeters(driver, polyline)
        : 0.0;
    final shouldReroute =
        !isEstimated && polyline.length >= 6 && off > offRouteMeters;

    if (steps.isEmpty) {
      return TurnCue(
        instruction: '',
        maneuver: '',
        metersToManeuver: 0,
        remainingMeters: 0,
        remainingMinutes: 1,
        metersOffRoute: off,
        offRoute: shouldReroute,
      );
    }

    var index = 0;
    for (var i = 0; i < steps.length; i++) {
      final toEnd = haversineMeters(driver, steps[i].end);
      if (toEnd <= stepAdvanceMeters && i < steps.length - 1) {
        index = i + 1;
        continue;
      }
      index = i;
      break;
    }

    final current = steps[index];
    var remaining = haversineMeters(driver, current.end);
    var seconds = current.durationSeconds <= 0
        ? 0
        : (current.durationSeconds *
                (remaining / math.max(current.distanceMeters, 1)))
            .round();
    for (var i = index + 1; i < steps.length; i++) {
      remaining += steps[i].distanceMeters;
      seconds += steps[i].durationSeconds;
    }

    return TurnCue(
      instruction: current.instruction,
      maneuver: current.maneuver,
      metersToManeuver: haversineMeters(driver, current.end).round(),
      remainingMeters: remaining.round().clamp(0, 1 << 30),
      remainingMinutes: math.max(1, (seconds / 60).ceil()),
      metersOffRoute: off,
      offRoute: shouldReroute,
    );
  }

  static int haversineMeters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final lat1 = _rad(a.latitude);
    final lat2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return (2 * earth * math.asin(math.min(1, math.sqrt(h)))).round();
  }

  static double distanceToPolylineMeters(LatLng point, List<LatLng> line) {
    if (line.isEmpty) return double.infinity;
    if (line.length == 1) return haversineMeters(point, line.first).toDouble();
    var best = double.infinity;
    for (var i = 0; i < line.length - 1; i++) {
      final d = _distanceToSegmentMeters(point, line[i], line[i + 1]);
      if (d < best) best = d;
    }
    return best;
  }

  static double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
    final origin = a;
    final ap = _xy(p, origin);
    final ab = _xy(b, origin);
    final abLen2 = ab.$1 * ab.$1 + ab.$2 * ab.$2;
    if (abLen2 < 1) return haversineMeters(p, a).toDouble();
    final t = ((ap.$1 * ab.$1 + ap.$2 * ab.$2) / abLen2).clamp(0.0, 1.0);
    final dx = ap.$1 - ab.$1 * t;
    final dy = ap.$2 - ab.$2 * t;
    return math.sqrt(dx * dx + dy * dy);
  }

  static (double, double) _xy(LatLng p, LatLng origin) {
    const earth = 6371000.0;
    final x = _rad(p.longitude - origin.longitude) *
        earth *
        math.cos(_rad(origin.latitude));
    final y = _rad(p.latitude - origin.latitude) * earth;
    return (x, y);
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static String stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<NavigationStep> parseDirectionSteps(List<dynamic>? raw) {
    if (raw == null) return const [];
    final steps = <NavigationStep>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final instruction = stripHtml(
        (map['instruction'] ?? map['html_instructions'] ?? '').toString(),
      );
      final start = _latLng(map['start'] ?? map['start_location']);
      final end = _latLng(map['end'] ?? map['end_location']);
      if (start == null || end == null) continue;
      final distance = map['distanceMeters'] ??
          (map['distance'] is Map ? (map['distance'] as Map)['value'] : null);
      final duration = map['durationSeconds'] ??
          (map['duration'] is Map ? (map['duration'] as Map)['value'] : null);
      steps.add(
        NavigationStep(
          instruction: instruction.isEmpty ? 'Continue' : instruction,
          maneuver: (map['maneuver'] ?? '').toString(),
          distanceMeters: (distance as num?)?.round() ?? 0,
          durationSeconds: (duration as num?)?.round() ?? 0,
          start: start,
          end: end,
        ),
      );
    }
    return steps;
  }

  static LatLng? _latLng(Object? raw) {
    if (raw is! Map) return null;
    final lat = (raw['lat'] ?? raw['latitude']) as num?;
    final lng = (raw['lng'] ?? raw['longitude']) as num?;
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  static String formatDistance(int meters, {required bool arabic}) {
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1);
      return arabic ? '$km كم' : '$km km';
    }
    return arabic ? '$meters م' : '$meters m';
  }
}
