import 'dart:js_interop';

import 'package:latlong2/latlong.dart';

@JS('hillaReverseGeocode')
external JSPromise<JSString> _hillaReverseGeocode(
  JSNumber lat,
  JSNumber lng,
  JSString languageCode,
);

Future<String?> fetchWebReverseGeocode(
  LatLng point, {
  required String languageCode,
}) async {
  try {
    final result = await _hillaReverseGeocode(
      point.latitude.toJS,
      point.longitude.toJS,
      languageCode.toJS,
    ).toDart;
    final label = result.toDart.trim();
    return label.isEmpty ? null : label;
  } catch (_) {
    return null;
  }
}
