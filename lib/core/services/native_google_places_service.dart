import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:latlong2/latlong.dart' as ll;

class NativeGooglePlacesService {
  NativeGooglePlacesService({FlutterGooglePlacesSdk? sdk})
      : _sdk = sdk ?? FlutterGooglePlacesSdk(MapsConfig.androidMapApiKey);

  final FlutterGooglePlacesSdk _sdk;

  static const Duration _timeout = Duration(seconds: 10);
  static const List<PlaceField> _fields = [
    PlaceField.DisplayName,
    PlaceField.FormattedAddress,
    PlaceField.Location,
  ];

  bool _failed = false;
  bool _succeeded = false;

  bool get isApiDenied => _failed;
  bool get isAvailable => _succeeded && !_failed;

  Future<List<PlaceResult>> searchPlaces({
    required String query,
    required ll.LatLng center,
    required double radiusKm,
    required RegionSearchContext region,
    String? regionLabel,
  }) async {
    if (_failed || query.trim().isEmpty) return const [];

    final enrichedQuery = regionLabel == null || regionLabel.isEmpty
        ? query.trim()
        : '${query.trim()} $regionLabel Babil Iraq';

    try {
      final response = await _sdk
          .searchByText(
            enrichedQuery,
            fields: _fields,
            locationRestriction: _bounds(center, radiusKm),
            regionCode: 'iq',
            maxResultCount: 20,
          )
          .timeout(_timeout);

      _succeeded = true;
      return _filterPlaces(response.places, region);
    } catch (error, stackTrace) {
      _markFailed('text search', error, stackTrace);
      return const [];
    }
  }

  Future<List<PlaceResult>> nearbyPlaces({
    required ll.LatLng center,
    required double radiusKm,
    required RegionSearchContext region,
  }) async {
    if (_failed) return const [];

    try {
      final response = await _sdk
          .searchNearby(
            fields: _fields,
            locationRestriction: CircularBounds(
              center: LatLng(lat: center.latitude, lng: center.longitude),
              radius: radiusKm * 1000,
            ),
            regionCode: 'iq',
            maxResultCount: 20,
          )
          .timeout(_timeout);

      _succeeded = true;
      return _filterPlaces(response.places, region);
    } catch (error, stackTrace) {
      _markFailed('nearby search', error, stackTrace);
      return const [];
    }
  }

  List<PlaceResult> _filterPlaces(
    List<Place> places,
    RegionSearchContext region,
  ) {
    if (!region.hasSubDistrict) return const [];

    return places
        .map(_toPlaceResult)
        .whereType<PlaceResult>()
        .where(
          (place) => BabilRegions.isWithinSubDistrict(
            region.districtId,
            region.subDistrictId!,
            ll.LatLng(place.latitude, place.longitude),
          ),
        )
        .toList();
  }

  PlaceResult? _toPlaceResult(Place place) {
    final latLng = place.latLng;
    if (latLng == null) return null;

    final displayName = place.displayName?.text?.trim() ?? '';
    final address = place.address?.trim() ?? '';
    final name = place.name?.trim() ?? '';
    final label = switch ((displayName.isEmpty, address.isEmpty, name.isEmpty)) {
      (true, true, true) => null,
      (true, true, false) => name,
      (true, false, _) => address,
      (false, true, _) => displayName,
      _ => '$displayName, $address',
    };
    if (label == null || label.isEmpty) return null;

    return PlaceResult(
      label: label,
      latitude: latLng.lat,
      longitude: latLng.lng,
    );
  }

  LatLngBounds _bounds(ll.LatLng center, double radiusKm) {
    final latDelta = radiusKm / 111.0;
    final lngDelta =
        radiusKm / (111.0 * math.cos(center.latitude * math.pi / 180));
    return LatLngBounds(
      southwest: LatLng(
        lat: center.latitude - latDelta,
        lng: center.longitude - lngDelta,
      ),
      northeast: LatLng(
        lat: center.latitude + latDelta,
        lng: center.longitude + lngDelta,
      ),
    );
  }

  void _markFailed(String operation, Object error, StackTrace stackTrace) {
    _failed = true;
    if (kDebugMode) {
      debugPrint('Native Google Places $operation failed: $error');
      debugPrint('$stackTrace');
    }
  }
}
