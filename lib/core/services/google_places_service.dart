import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Google Places API (New) — Text Search, Nearby Search, and reverse geocode.
///
/// Legacy Places Text/Nearby Search (`maps/api/place/...`) is disabled in
/// Google Cloud project taxiapp2024; this service uses the New endpoints instead.
class GooglePlacesService {
  GooglePlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);
  static const _textSearchUrl =
      'https://places.googleapis.com/v1/places:searchText';
  static const _nearbySearchUrl =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const _fieldMask =
      'places.displayName,places.formattedAddress,places.location';

  bool _apiDenied = false;
  bool _loggedDenied = false;

  bool get isApiDenied => _apiDenied;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': MapsConfig.placesWebApiKey,
        'X-Goog-FieldMask': _fieldMask,
      };

  Future<List<PlaceResult>> searchPlaces({
    required String query,
    required LatLng center,
    required double radiusKm,
    String languageCode = 'ar',
    String? regionLabel,
  }) async {
    if (!MapsConfig.useGooglePlacesHttp || _apiDenied || query.trim().isEmpty) {
      return const [];
    }

    final enrichedQuery = regionLabel == null || regionLabel.isEmpty
        ? query.trim()
        : '${query.trim()} $regionLabel Babil Iraq';

    try {
      final response = await _client
          .post(
            Uri.parse(_textSearchUrl),
            headers: _headers,
            body: jsonEncode({
              'textQuery': enrichedQuery,
              'languageCode': languageCode,
              'regionCode': 'iq',
              'maxResultCount': 20,
              'locationBias': {
                'circle': {
                  'center': {
                    'latitude': center.latitude,
                    'longitude': center.longitude,
                  },
                  'radius': radiusKm * 1000,
                },
              },
            }),
          )
          .timeout(_timeout);

      if (!_isSuccess(response)) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseNewPlaces(data['places'] as List<dynamic>?);
    } catch (error) {
      if (kDebugMode) debugPrint('Google Places text search failed: $error');
      return const [];
    }
  }

  Future<List<PlaceResult>> nearbyPlaces({
    required LatLng center,
    required double radiusKm,
    String languageCode = 'ar',
    String? keyword,
    String? type,
  }) async {
    if (!MapsConfig.useGooglePlacesHttp || _apiDenied) return const [];

    try {
      final body = <String, dynamic>{
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': center.latitude,
              'longitude': center.longitude,
            },
            'radius': radiusKm * 1000,
          },
        },
        'languageCode': languageCode,
        'regionCode': 'iq',
        'maxResultCount': 20,
      };
      if (keyword != null && keyword.isNotEmpty) {
        body['includedTypes'] = [keyword];
      }
      if (type != null && type.isNotEmpty) {
        body['includedPrimaryTypes'] = [type];
      }

      final response = await _client
          .post(
            Uri.parse(_nearbySearchUrl),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (!_isSuccess(response)) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseNewPlaces(data['places'] as List<dynamic>?);
    } catch (error) {
      if (kDebugMode) debugPrint('Google Places nearby search failed: $error');
      return const [];
    }
  }

  Future<String> reverseGeocode(
    LatLng point, {
    String languageCode = 'ar',
  }) async {
    if (!MapsConfig.useGooglePlacesHttp || _apiDenied) {
      return _coordLabel(point);
    }

    try {
      final response = await _client
          .post(
            Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
            headers: _headers,
            body: jsonEncode({
              'locationRestriction': {
                'circle': {
                  'center': {
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                  },
                  'radius': 50.0,
                },
              },
              'languageCode': languageCode,
              'regionCode': 'iq',
              'maxResultCount': 1,
            }),
          )
          .timeout(_timeout);

      if (!_isSuccess(response)) return _coordLabel(point);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = _parseNewPlaces(data['places'] as List<dynamic>?);
      if (places.isEmpty) return _coordLabel(point);
      return places.first.label;
    } catch (_) {
      return _coordLabel(point);
    }
  }

  List<PlaceResult> _parseNewPlaces(List<dynamic>? places) {
    if (places == null || places.isEmpty) return const [];

    return places.map((item) {
      final map = item as Map<String, dynamic>;
      final location = map['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      final lat = (location['latitude'] as num?)?.toDouble();
      final lng = (location['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final displayName = map['displayName'] as Map<String, dynamic>?;
      final name = displayName?['text'] as String? ?? '';
      final address = map['formattedAddress'] as String? ?? '';
      final label = switch ((name.isEmpty, address.isEmpty)) {
        (true, true) => null,
        (true, false) => address,
        (false, true) => name,
        _ => '$name, $address',
      };
      if (label == null || label.isEmpty) return null;

      return PlaceResult(label: label, latitude: lat, longitude: lng);
    }).whereType<PlaceResult>().toList();
  }

  bool _isSuccess(http.Response response) {
    if (response.statusCode == 200) return true;

    if (response.statusCode == 403 || response.statusCode == 401) {
      _apiDenied = true;
      if (kDebugMode && !_loggedDenied) {
        _loggedDenied = true;
        debugPrint(
          'Google Places API (New) denied (${response.statusCode}): '
          '${response.body}. Enable Places API (New) on key '
          '${MapsConfig.placesWebApiKeyEmbedded.substring(0, 8)}… '
          'in project taxiapp2024.',
        );
      }
    }

    return false;
  }

  String _coordLabel(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
}
