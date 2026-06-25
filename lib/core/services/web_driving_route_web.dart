import 'dart:js_interop';

import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/utils/polyline_codec.dart';
import 'package:latlong2/latlong.dart';

@JS('hillaGetDrivingRoute')
external JSPromise<_RoutePayload?> _hillaGetDrivingRoute(
  JSNumber originLat,
  JSNumber originLng,
  JSNumber destLat,
  JSNumber destLng,
);

@JS('hillaGetDrivingPolyline')
external JSPromise<_PolylinePayload?> _hillaGetDrivingPolyline(
  JSNumber originLat,
  JSNumber originLng,
  JSNumber destLat,
  JSNumber destLng,
);

@JS()
extension type _RoutePayload._(JSObject _) implements JSObject {
  external int get distanceMeters;
  external int get durationSeconds;
}

@JS()
extension type _PolylinePayload._(JSObject _) implements JSObject {
  external JSString get encodedPolyline;
}

Future<DrivingRouteInfo?> fetchWebDrivingRoute(
  LatLng origin,
  LatLng destination,
) async {
  try {
    final payload = await _hillaGetDrivingRoute(
      origin.latitude.toJS,
      origin.longitude.toJS,
      destination.latitude.toJS,
      destination.longitude.toJS,
    ).toDart;
    if (payload == null || payload.distanceMeters <= 0) return null;

    final distanceKm =
        (payload.distanceMeters / 1000 * 100).round() / 100;
    final durationMinutes =
        (payload.durationSeconds / 60).ceil().clamp(1, 120);

    return DrivingRouteInfo(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      isEstimated: false,
    );
  } catch (_) {
    return null;
  }
}

Future<List<LatLng>?> fetchWebDrivingPolyline(
  LatLng origin,
  LatLng destination,
) async {
  try {
    final payload = await _hillaGetDrivingPolyline(
      origin.latitude.toJS,
      origin.longitude.toJS,
      destination.latitude.toJS,
      destination.longitude.toJS,
    ).toDart;
    if (payload == null) return null;

    final encoded = payload.encodedPolyline.toDart;
    if (encoded.isEmpty) return null;

    final points = decodePolyline(encoded);
    return points.length >= 2 ? points : null;
  } catch (_) {
    return null;
  }
}
