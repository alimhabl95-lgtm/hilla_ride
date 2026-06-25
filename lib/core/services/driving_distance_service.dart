import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/services/web_driving_route_stub.dart'
    if (dart.library.js_interop) 'package:hilla_ride/core/services/web_driving_route_web.dart';
import 'package:hilla_ride/core/utils/polyline_codec.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class DrivingRouteInfo {
  const DrivingRouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
    this.isEstimated = false,
  });

  final double distanceKm;
  final int durationMinutes;

  /// True when Google route APIs were unavailable and distance was estimated.
  final bool isEstimated;
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
  static const Duration _timeout = Duration(seconds: 6);
  static const Duration _cloudTimeout = Duration(seconds: 4);
  static const _routesUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _roadFactor = 1.3;

  Future<DrivingRouteInfo> getDrivingRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    if (!MapsConfig.useGooglePlacesHttp) {
      return _estimateFromStraightLine(origin, destination);
    }

    final cloudRoute = kIsWeb
        ? null
        : await _tryCloudFunctionRoute(origin, destination);
    if (cloudRoute != null) return cloudRoute;

    if (kIsWeb) {
      try {
        final webRoute = await fetchWebDrivingRoute(origin, destination)
            .timeout(_timeout, onTimeout: () => null);
        if (webRoute != null) return webRoute;
      } catch (error) {
        if (kDebugMode) debugPrint('Web driving route failed: $error');
      }
      return _estimateFromStraightLine(origin, destination);
    }

    final key = MapsConfig.placesWebApiKey;

    for (final attempt in [
      () => _tryDistanceMatrix(origin, destination, key),
      () => _tryDirectionsApi(origin, destination, key),
      () => _tryRoutesApi(origin, destination, key),
    ]) {
      try {
        final result = await attempt();
        if (result != null) return result;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Driving distance attempt failed: $error');
        }
      }
    }

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
    if (!MapsConfig.useGooglePlacesHttp) {
      return _straightLinePoints(origin, destination);
    }

    final cloudPolyline = kIsWeb
        ? null
        : await _tryCloudFunctionPolyline(origin, destination);
    if (cloudPolyline != null && cloudPolyline.length >= 2) {
      return cloudPolyline;
    }

    if (kIsWeb) {
      final points = await fetchWebDrivingPolyline(origin, destination);
      if (points != null) return points;
    } else {
      final key = MapsConfig.placesWebApiKey;
      for (final attempt in [
        () => _tryDirectionsPolyline(origin, destination, key),
        () => _tryRoutesPolyline(origin, destination, key),
      ]) {
        try {
          final points = await attempt();
          if (points != null && points.length >= 2) return points;
        } catch (error) {
          if (kDebugMode) debugPrint('Route polyline attempt failed: $error');
        }
      }
    }

    return _straightLinePoints(origin, destination);
  }

  Future<DrivingRouteInfo?> _tryCloudFunctionRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final callable = _functions.httpsCallable('getDrivingRoute');
      final result = await callable
          .call({
            'originLat': origin.latitude,
            'originLng': origin.longitude,
            'destLat': destination.latitude,
            'destLng': destination.longitude,
          })
          .timeout(_cloudTimeout);
      final data = Map<String, dynamic>.from(result.data as Map);
      final distanceKm = (data['distanceKm'] as num?)?.toDouble();
      final durationMinutes = (data['durationMinutes'] as num?)?.toInt();
      if (distanceKm == null || durationMinutes == null) return null;

      return DrivingRouteInfo(
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        isEstimated: false,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Cloud driving route failed: $error');
      return null;
    }
  }

  Future<List<LatLng>?> _tryCloudFunctionPolyline(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final callable = _functions.httpsCallable('getDrivingRoute');
      final result = await callable
          .call({
            'originLat': origin.latitude,
            'originLng': origin.longitude,
            'destLat': destination.latitude,
            'destLng': destination.longitude,
          })
          .timeout(_cloudTimeout);
      final data = Map<String, dynamic>.from(result.data as Map);
      final encoded = data['encodedPolyline'] as String? ?? '';
      if (encoded.isEmpty) return null;
      return decodePolyline(encoded);
    } catch (error) {
      if (kDebugMode) debugPrint('Cloud route polyline failed: $error');
      return null;
    }
  }

  Future<List<LatLng>?> _tryDirectionsPolyline(
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
    if (data['status'] != 'OK') return null;

    final routes = data['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) return null;

    final polyline = (routes.first as Map<String, dynamic>)['overview_polyline']
        as Map<String, dynamic>?;
    final encoded = polyline?['points'] as String?;
    if (encoded == null || encoded.isEmpty) return null;

    return decodePolyline(encoded);
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
