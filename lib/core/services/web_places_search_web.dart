import 'dart:js_interop';

import 'package:hilla_ride/core/models/app_models.dart';
import 'package:latlong2/latlong.dart';

@JS('hillaSearchPlaces')
external JSPromise<JSArray<_WebPlaceResult>?> _hillaSearchPlaces(
  JSString query,
  JSNumber lat,
  JSNumber lng,
  JSNumber radiusMeters,
  JSString languageCode,
);

@JS('hillaNearbyPlaces')
external JSPromise<JSArray<_WebPlaceResult>?> _hillaNearbyPlaces(
  JSNumber lat,
  JSNumber lng,
  JSNumber radiusMeters,
  JSString languageCode,
);

@JS('hillaPlacesApiReady')
external JSFunction get _hillaPlacesApiReadyFn;

@JS()
extension type _WebPlaceResult._(JSObject _) implements JSObject {
  external JSString get name;
  external JSString get address;
  external JSNumber get lat;
  external JSNumber get lng;
}

Future<bool> get webPlacesApiReady async =>
    (_hillaPlacesApiReadyFn.callAsFunction() as JSBoolean?)?.toDart ?? false;

Future<List<PlaceResult>?> fetchWebPlacesSearch({
  required String query,
  required LatLng center,
  required double radiusKm,
  required String languageCode,
  String? regionLabel,
}) async {
  final enrichedQuery = regionLabel == null || regionLabel.isEmpty
      ? query.trim()
      : '${query.trim()} $regionLabel Babil Iraq';

  if (!await _waitForWebPlacesReady()) {
    return null;
  }

  try {
    final results = await _hillaSearchPlaces(
      enrichedQuery.toJS,
      center.latitude.toJS,
      center.longitude.toJS,
      (radiusKm * 1000).round().toJS,
      languageCode.toJS,
    ).toDart;

    return _parseResults(results);
  } catch (_) {
    return null;
  }
}

Future<List<PlaceResult>?> fetchWebPlacesNearby({
  required LatLng center,
  required double radiusKm,
  required String languageCode,
}) async {
  if (!await _waitForWebPlacesReady()) {
    return null;
  }

  try {
    final results = await _hillaNearbyPlaces(
      center.latitude.toJS,
      center.longitude.toJS,
      (radiusKm * 1000).round().toJS,
      languageCode.toJS,
    ).toDart;

    return _parseResults(results);
  } catch (_) {
    return null;
  }
}

Future<bool> _waitForWebPlacesReady() async {
  for (var attempt = 0; attempt < 40; attempt++) {
    if (await webPlacesApiReady) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

List<PlaceResult>? _parseResults(JSArray<_WebPlaceResult>? results) {
  if (results == null) return null;

  final places = <PlaceResult>[];
  final length = results.length;
  for (var i = 0; i < length; i++) {
    final item = results[i];
    final name = item.name.toDart;
    final address = item.address.toDart;
    final label = address.isEmpty
        ? name
        : name.isEmpty
            ? address
            : '$name, $address';
    if (label.isEmpty) continue;

    places.add(
      PlaceResult(
        label: label,
        latitude: item.lat.toDartDouble,
        longitude: item.lng.toDartDouble,
      ),
    );
  }

  return places;
}
