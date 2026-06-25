import 'package:hilla_ride/core/models/app_models.dart';
import 'package:latlong2/latlong.dart';

Future<List<PlaceResult>?> fetchWebPlacesSearch({
  required String query,
  required LatLng center,
  required double radiusKm,
  required String languageCode,
  String? regionLabel,
}) async {
  return null;
}

Future<List<PlaceResult>?> fetchWebPlacesNearby({
  required LatLng center,
  required double radiusKm,
  required String languageCode,
}) async {
  return null;
}

Future<bool> get webPlacesApiReady async => false;
