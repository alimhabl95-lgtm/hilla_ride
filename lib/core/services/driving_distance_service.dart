import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/services/web_driving_route_stub.dart'
    if (dart.library.js_interop) 'package:hilla_ride/core/services/web_driving_route_web.dart';
import 'package:hilla_ride/core/services/turn_by_turn_guide.dart';
import 'package:hilla_ride/core/utils/polyline_codec.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DrivingRouteInfo {
  const DrivingRouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    this.isEstimated = false,
    this.polylinePoints = const [],
    this.steps = const [],
  });

  final double distanceKm;
  final int durationMinutes;

  /// True when Google route APIs were unavailable and distance was estimated.
  final bool isEstimated;

  /// Decoded road geometry when available (empty for estimate-only results).
  final List<LatLng> polylinePoints;

  /// Turn-by-turn steps when the route came from Directions.
  final List<NavigationStep> steps;
}

/// Driving distance via Firebase Cloud Function / Google APIs, with fallback.
class DrivingDistanceService {
  DrivingDistanceService({
    http.Client? client,
    FirebaseFunctions? functions,
  })  : _client = client ?? http.Client(),
        _functions = functions ?? FirebaseFunctions.instance;

  final http.Client _client;
  final FirebaseFunctions _functions;
  static const Duration _timeout = Duration(seconds: 8);
  static const Duration _cloudTimeout = Duration(seconds: 8);
  static const _routesUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _roadFactor = 1.3;

  Future<DrivingRouteInfo> getDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    final detailed = await getDrivingRouteDetails(origin, destination);
    return detailed;
  }

  /// Single call that returns ETA/distance plus road polyline when possible.
  Future<DrivingRouteInfo> getDrivingRouteDetails(
    LatLng origin,
    LatLng destination, {
    String languageCode = 'ar',
  }) async {
    if (!MapsConfig.useGooglePlacesHttp) {
      return _estimateFromStraightLine(origin, destination);
    }

    DrivingRouteInfo? cloudRoute;
    if (!kIsWeb) {
      cloudRoute = await _tryCloudFunctionRouteDetails(
        origin,
        destination,
        languageCode: languageCode,
      );
      if (cloudRoute != null && cloudRoute.steps.isNotEmpty) return cloudRoute;
    }

    if (kIsWeb) {
      try {
        final webRoute = await fetchWebDrivingRoute(origin, destination)
            .timeout(_timeout, onTimeout: () => null);
        if (webRoute != null) {
          final points = await fetchWebDrivingPolyline(origin, destination);
          return DrivingRouteInfo(
            distanceKm: webRoute.distanceKm,
            durationMinutes: webRoute.durationMinutes,
            isEstimated: webRoute.isEstimated,
            polylinePoints: points ?? _straightLinePoints(origin, destination),
          );
        }
      } catch (error) {
        if (kDebugMode) debugPrint('Web driving route failed: $error');
      }
      return _estimateFromStraightLine(origin, destination);
    }

    final key = MapsConfig.placesWebApiKey;

    try {
      final directions = await _tryDirectionsRouteDetails(
        origin,
        destination,
        key,
        languageCode: languageCode,
      );
      if (directions != null) return directions;
    } catch (error) {
      if (kDebugMode) debugPrint('Directions route details failed: $error');
    }

    for (final attempt in [
      () => _tryDistanceMatrix(origin, destination, key),
      () => _tryDirectionsApi(origin, destination, key),
      () => _tryRoutesApi(origin, destination, key),
    ]) {
      try {
        final result = await attempt();
        if (result != null) {
          List<LatLng> points = const [];
          try {
            final fromDirections =
                await _tryDirectionsPolyline(origin, destination, key);
            if (fromDirections != null && fromDirections.length >= 2) {
              points = fromDirections;
            } else {
              final fromRoutes =
                  await _tryRoutesPolyline(origin, destination, key);
              if (fromRoutes != null && fromRoutes.length >= 2) {
                points = fromRoutes;
              }
            }
          } catch (_) {}
          return DrivingRouteInfo(
            distanceKm: result.distanceKm,
            durationMinutes: result.durationMinutes,
            isEstimated: result.isEstimated,
            polylinePoints: points.length >= 2
                ? points
                : _straightLinePoints(origin, destination),
          );
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Driving distance attempt failed: $error');
        }
      }
    }

    if (cloudRoute != null) return cloudRoute;

    if (kDebugMode) {
      debugPrint(
        'All route sources failed. Using straight-line estimate.',
      );
    }
    return _estimateFromStraightLine(origin, destination);
  }

  Future<List<LatLng>> getRoutePolylinePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    final detailed = await getDrivingRouteDetails(origin, destination);
    if (detailed.polylinePoints.length >= 2) {
      return detailed.polylinePoints;
    }
    return _straightLinePoints(origin, destination);
  }

  Future<DrivingRouteInfo?> _tryCloudFunctionRouteDetails(
    LatLng origin,
    LatLng destination, {
    String languageCode = 'ar',
  }) async {
    try {
      final callable = _functions.httpsCallable('getDrivingRoute');
      final result = await callable
          .call({
            'originLat': origin.latitude,
            'originLng': origin.longitude,
            'destLat': destination.latitude,
            'destLng': destination.longitude,
            'language': languageCode,
          })
          .timeout(_cloudTimeout);
      final data = Map<String, dynamic>.from(result.data as Map);
      final distanceKm = (data['distanceKm'] as num?)?.toDouble();
      final durationMinutes = (data['durationMinutes'] as num?)?.toInt();
      if (distanceKm == null || durationMinutes == null) return null;

      final encoded = data['encodedPolyline'] as String? ?? '';
      final points = encoded.isEmpty
          ? _straightLinePoints(origin, destination)
          : decodePolyline(encoded);
      final steps = TurnByTurnGuide.parseDirectionSteps(
        data['steps'] as List<dynamic>?,
      );

      return DrivingRouteInfo(
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        isEstimated: false,
        polylinePoints: points.length >= 2
            ? points
            : _straightLinePoints(origin, destination),
        steps: steps,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Cloud driving route failed: $error');
      return null;
    }
  }

  Future<DrivingRouteInfo?> _tryDirectionsRouteDetails(
    LatLng origin,
    LatLng destination,
    String key, {
    String languageCode = 'ar',
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': key,
      'region': 'iq',
      'language': languageCode,
    });

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? const [];
    if (legs.isEmpty) return null;
    final leg = legs.first as Map<String, dynamic>;
    final distanceMeters = (leg['distance'] as Map?)?['value'] as num?;
    final durationSeconds = (leg['duration'] as Map?)?['value'] as num?;
    if (distanceMeters == null || durationSeconds == null) return null;

    final polyline = route['overview_polyline'] as Map<String, dynamic>?;
    final encoded = polyline?['points'] as String?;
    final points = (encoded == null || encoded.isEmpty)
        ? _straightLinePoints(origin, destination)
        : decodePolyline(encoded);
    final steps = TurnByTurnGuide.parseDirectionSteps(
      leg['steps'] as List<dynamic>?,
    );

    return DrivingRouteInfo(
      distanceKm: distanceMeters / 1000.0,
      durationMinutes: (durationSeconds / 60).ceil().clamp(1, 9999),
      isEstimated: false,
      polylinePoints: points.length >= 2
          ? points
          : _straightLinePoints(origin, destination),
      steps: steps,
    );
  }

  Future<List<LatLng>?> _tryDirectionsPolyline(
    LatLng origin,
    LatLng destination,
    String key,
  ) async {
    final detailed =
        await _tryDirectionsRouteDetails(origin, destination, key);
    if (detailed == null || detailed.polylinePoints.length < 2) return null;
    return detailed.polylinePoints;
  }

  Future<List<LatLng>?> _tryRoutesPolyline(
    LatLng origin,
    LatLng destination,
    String key,
  ) async {
    final response = await _client
        .post(
          Uri.parse(_routesUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask': 'routes.polyline.encodedPolyline',
          },
          body: jsonEncode({
            'origin': {
              'location': {
                'latLng': {
                  'latitude': origin.latitude,
                  'longitude': origin.longitude,
                },
              },
            },
            'destination': {
              'location': {
                'latLng': {
                  'latitude': destination.latitude,
                  'longitude': destination.longitude,
                },
              },
            },
            'travelMode': 'DRIVE',
            'routingPreference': 'TRAFFIC_AWARE',
            'computeAlternativeRoutes': false,
            'languageCode': 'ar-IQ',
            'units': 'METRIC',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;

    final polyline = (routes.first as Map<String, dynamic>)['polyline']
        as Map<String, dynamic>?;
    final encoded = polyline?['encodedPolyline'] as String?;
    if (encoded == null || encoded.isEmpty) return null;

    return decodePolyline(encoded);
  }

  List<LatLng> _straightLinePoints(LatLng origin, LatLng destination) {
    const segments = 12;
    final points = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      points.add(
        LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * t,
          origin.longitude + (destination.longitude - origin.longitude) * t,
        ),
      );
    }
    return points;
  }

  Future<DrivingRouteInfo?> _tryRoutesApi(
    LatLng origin,
    LatLng destination,
    String key,
  ) async {
    final response = await _client
        .post(
          Uri.parse(_routesUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
          },
          body: jsonEncode({
            'origin': {
              'location': {
                'latLng': {
                  'latitude': origin.latitude,
                  'longitude': origin.longitude,
                },
              },
            },
            'destination': {
              'location': {
                'latLng': {
                  'latitude': destination.latitude,
                  'longitude': destination.longitude,
                },
              },
            },
            'travelMode': 'DRIVE',
            'routingPreference': 'TRAFFIC_AWARE',
            'computeAlternativeRoutes': false,
            'languageCode': 'ar-IQ',
            'units': 'METRIC',
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint('Routes API HTTP ${response.statusCode}: ${response.body}');
      }
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final distanceMeters = route['distanceMeters'] as num?;
    final durationRaw = route['duration'] as String?;
    if (distanceMeters == null || durationRaw == null) return null;

    return _fromMeters(
      distanceMeters,
      _parseDurationSeconds(durationRaw),
      isEstimated: false,
    );
  }

  Future<DrivingRouteInfo?> _tryDistanceMatrix(
    LatLng origin,
    LatLng destination,
    String key,
  ) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/distancematrix/json', {
      'origins': '${origin.latitude},${origin.longitude}',
      'destinations': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': key,
      'region': 'iq',
    });

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final rows = data['rows'] as List<dynamic>? ?? const [];
    if (rows.isEmpty) return null;

    final elements = (rows.first as Map<String, dynamic>)['elements'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) return null;

    final element = elements.first as Map<String, dynamic>;
    if (element['status'] != 'OK') return null;

    final distanceMeters =
        (element['distance'] as Map<String, dynamic>?)?['value'] as num?;
    final durationSeconds =
        (element['duration'] as Map<String, dynamic>?)?['value'] as num?;
    if (distanceMeters == null || durationSeconds == null) return null;

    return _fromMeters(distanceMeters, durationSeconds.toInt(), isEstimated: false);
  }

  Future<DrivingRouteInfo?> _tryDirectionsApi(
    LatLng origin,
    LatLng destination,
    String key,
  ) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'key': key,
      'region': 'iq',
    });

    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      if (kDebugMode) {
        debugPrint('Directions API: ${data['error_message'] ?? data['status']}');
      }
      return null;
    }

    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;

    final legs = (routes.first as Map<String, dynamic>)['legs'] as List<dynamic>?;
    if (legs == null || legs.isEmpty) return null;

    final leg = legs.first as Map<String, dynamic>;
    final distanceMeters =
        (leg['distance'] as Map<String, dynamic>?)?['value'] as num?;
    final durationSeconds =
        (leg['duration'] as Map<String, dynamic>?)?['value'] as num?;
    if (distanceMeters == null || durationSeconds == null) return null;

    return _fromMeters(distanceMeters, durationSeconds.toInt(), isEstimated: false);
  }

  DrivingRouteInfo estimateRouteSync(LatLng origin, LatLng destination) {
    return _estimateFromStraightLine(origin, destination);
  }

  DrivingRouteInfo _estimateFromStraightLine(LatLng origin, LatLng destination) {
    const distance = Distance();
    final straightKm = distance.as(LengthUnit.Kilometer, origin, destination);
    final estimatedKm = ((straightKm * _roadFactor) * 100).round() / 100;
    final durationMinutes = (estimatedKm * 3).ceil().clamp(3, 45);

    return DrivingRouteInfo(
      distanceKm: estimatedKm,
      durationMinutes: durationMinutes,
      isEstimated: true,
      polylinePoints: _straightLinePoints(origin, destination),
    );
  }

  DrivingRouteInfo _fromMeters(
    num distanceMeters,
    int durationSeconds, {
    required bool isEstimated,
  }) {
    final distanceKm = (distanceMeters / 1000 * 100).round() / 100;
    final durationMinutes = (durationSeconds / 60).ceil().clamp(1, 120);

    return DrivingRouteInfo(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      isEstimated: isEstimated,
    );
  }

  int _parseDurationSeconds(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('s')) {
      return int.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 0;
    }
    return int.tryParse(trimmed) ?? 0;
  }
}
