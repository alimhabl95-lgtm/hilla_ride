import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/services/google_places_service.dart';
import 'package:hilla_ride/core/services/local_places_service.dart';
import 'package:hilla_ride/core/services/native_google_places_service.dart';
import 'package:hilla_ride/core/utils/street_address_formatter.dart';
import 'package:hilla_ride/core/services/web_geocoding_stub.dart'
    if (dart.library.js_interop) 'package:hilla_ride/core/services/web_geocoding_web.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  GeocodingService({
    http.Client? client,
    LocalPlacesService? localPlacesService,
    GooglePlacesService? googlePlacesService,
    NativeGooglePlacesService? nativeGooglePlacesService,
  })  : _client = client ?? http.Client(),
        _localPlaces = localPlacesService ?? LocalPlacesService(),
        _googlePlaces = googlePlacesService ?? GooglePlacesService(),
        _nativePlaces = nativeGooglePlacesService ?? NativeGooglePlacesService();

  final http.Client _client;
  final LocalPlacesService _localPlaces;
  final GooglePlacesService _googlePlaces;
  final NativeGooglePlacesService _nativePlaces;
  final Distance _distance = const Distance();
  bool _webGooglePlacesAvailable = false;
  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _coordinateLabel = RegExp(
    r'^-?\d+\.\d{4,6},\s*-?\d+\.\d{4,6}$',
  );

  bool _looksLikeCoordinateLabel(String value) =>
      _coordinateLabel.hasMatch(value.trim());

  static const Duration _requestTimeout = Duration(seconds: 6);
  static const Duration _overpassTimeout = Duration(seconds: 6);
  static const int _maxResults = 50;

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return _client.get(uri, headers: headers).timeout(_requestTimeout);
  }

  Future<List<PlaceResult>> searchPlacesInRegion(
    String query, {
    required RegionSearchContext region,
    String acceptLanguage = 'en',
  }) async {
    if (!region.hasSubDistrict) {
      return const [];
    }

    final trimmed = query.trim();
    final minLength = _arabicScript.hasMatch(trimmed) ? 1 : 2;
    if (trimmed.length < minLength) {
      return const [];
    }

    final languageCode = acceptLanguage.startsWith('ar') ? 'ar' : 'en';
    final center = region.searchCenter;
    final radiusKm = region.searchRadiusKm;
    final regionLabel = region.label(isArabic: acceptLanguage.startsWith('ar'));

    final localResults = await filterPlacesInRegion(
      trimmed,
      region,
      acceptLanguage: acceptLanguage,
    );

    List<PlaceResult> googleResults = await _searchGooglePlaces(
      query: trimmed,
      center: center,
      radiusKm: radiusKm,
      region: region,
      languageCode: languageCode,
      regionLabel: regionLabel,
    );

    final onlineResults = await Future.wait([
            _photonSearch(trimmed, acceptLanguage, center, radiusKm),
            _overpassSearch(trimmed, center, radiusKm),
            _nominatimSearch(
              trimmed,
              acceptLanguage,
              center,
              radiusKm,
              regionLabel,
            ),
          ]).timeout(
            const Duration(seconds: 10),
            onTimeout: () => const [[], [], []],
          );

    var merged = _mergeResultsInRegion(
      region: region,
      groups: [
        localResults,
        googleResults,
        ...onlineResults,
      ],
      allowDistrictFallback: false,
    );

    if (merged.isEmpty) {
      final categoryResults =
          await _overpassCategorySearch(trimmed, center, radiusKm);
      merged = _mergeResultsInRegion(
        region: region,
        groups: [categoryResults],
        allowDistrictFallback: false,
      );
    }

    return merged;
  }

  Future<List<PlaceResult>> _searchGooglePlaces({
    required String query,
    required LatLng center,
    required double radiusKm,
    required RegionSearchContext region,
    required String languageCode,
    required String regionLabel,
  }) async {
    if (!MapsConfig.useGooglePlacesHttp) {
      return const [];
    }

    // Places API (New) over HTTP — works on web, Android, and iOS.
    if (kIsWeb) {
      final webResults = await _googlePlaces.searchPlaces(
        query: query,
        center: center,
        radiusKm: radiusKm,
        languageCode: languageCode,
        regionLabel: regionLabel,
      );
      if (webResults.isNotEmpty) {
        _webGooglePlacesAvailable = true;
      }
      return webResults;
    }

    var googleResults = <PlaceResult>[];

    if (!_nativePlaces.isApiDenied) {
      final nativeResults = await _nativePlaces.searchPlaces(
        query: query,
        center: center,
        radiusKm: radiusKm,
        region: region,
        regionLabel: regionLabel,
      );
      if (nativeResults.isNotEmpty) {
        googleResults = nativeResults;
      }
    }

    if (!_googlePlaces.isApiDenied) {
      final httpResults = await _googlePlaces.searchPlaces(
        query: query,
        center: center,
        radiusKm: radiusKm,
        languageCode: languageCode,
        regionLabel: regionLabel,
      );
      googleResults = _dedupePlaces([...googleResults, ...httpResults]);
    }

    return googleResults;
  }

  List<PlaceResult> _dedupePlaces(List<PlaceResult> places) {
    final seen = <String>{};
    final merged = <PlaceResult>[];
    for (final place in places) {
      final key =
          '${place.latitude.toStringAsFixed(4)},${place.longitude.toStringAsFixed(4)}';
      if (seen.add(key)) {
        merged.add(place);
      }
    }
    return merged;
  }

  Future<List<PlaceResult>> _nearbyGooglePlaces({
    required LatLng center,
    required double radiusKm,
    required RegionSearchContext region,
    required String languageCode,
  }) async {
    if (!MapsConfig.useGooglePlacesHttp) {
      return const [];
    }

    if (kIsWeb) {
      final webResults = await _googlePlaces.nearbyPlaces(
        center: center,
        radiusKm: radiusKm,
        languageCode: languageCode,
      );
      if (webResults.isNotEmpty) {
        _webGooglePlacesAvailable = true;
      }
      return webResults;
    }

    var googleNearby = <PlaceResult>[];

    if (!_nativePlaces.isApiDenied) {
      final nativeResults = await _nativePlaces.nearbyPlaces(
        center: center,
        radiusKm: radiusKm,
        region: region,
      );
      if (nativeResults.isNotEmpty) {
        googleNearby = nativeResults;
      }
    }

    if (!_googlePlaces.isApiDenied) {
      final httpResults = await _googlePlaces.nearbyPlaces(
        center: center,
        radiusKm: radiusKm,
        languageCode: languageCode,
      );
      googleNearby = _dedupePlaces([...googleNearby, ...httpResults]);
    }

    return googleNearby;
  }

  bool get _hasGooglePlacesSource =>
      _nativePlaces.isAvailable ||
      _webGooglePlacesAvailable ||
      (!kIsWeb && MapsConfig.useGooglePlacesHttp && !_googlePlaces.isApiDenied);

  Future<List<PlaceResult>> listPlacesInRegion(
    RegionSearchContext region, {
    String acceptLanguage = 'en',
  }) async {
    if (!region.hasSubDistrict) {
      return const [];
    }

    final languageCode = acceptLanguage.startsWith('ar') ? 'ar' : 'en';
    final center = region.searchCenter;
    final radiusKm = region.searchRadiusKm;

    final local = await _localPlaces.listAll(preferArabic: true);
    final localInRegion = local
        .where(
          (place) => BabilRegions.isWithinSubDistrict(
            region.districtId,
            region.subDistrictId!,
            LatLng(place.latitude, place.longitude),
          ),
        )
        .toList();

    final googleNearby = await _nearbyGooglePlaces(
      center: center,
      radiusKm: radiusKm,
      region: region,
      languageCode: languageCode,
    );

    final osmNearby = await _overpassNearbyPois(center, radiusKm);

    return _mergeResultsInRegion(
      region: region,
      groups: [localInRegion, googleNearby, osmNearby],
      allowDistrictFallback: false,
    );
  }

  Future<List<PlaceResult>> filterPlacesInRegion(
    String query,
    RegionSearchContext region, {
    String acceptLanguage = 'en',
  }) async {
    if (!region.hasSubDistrict) {
      return const [];
    }

    final local = await _localPlaces.filter(query, preferArabic: true);
    return local
        .where(
          (place) => BabilRegions.isWithinSubDistrict(
            region.districtId,
            region.subDistrictId!,
            LatLng(place.latitude, place.longitude),
          ),
        )
        .toList();
  }

  Future<List<PlaceResult>> _overpassNearbyPois(
    LatLng center,
    double radiusKm,
  ) async {
    try {
      final delta = radiusKm / 111.0;
      final south = center.latitude - delta;
      final north = center.latitude + delta;
      final west = center.longitude - delta;
      final east = center.longitude + delta;

      final overpass = '''
[out:json][timeout:12];
(
  nwr["amenity"~"hospital|clinic|pharmacy|restaurant|bank|place_of_worship|university|college|school|marketplace|fuel|car_dealer"]($south,$west,$north,$east);
  nwr["shop"]($south,$west,$north,$east);
);
out center 30;
''';

      return _runOverpassQuery(overpass);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlaceResult>> _photonSearch(
    String query,
    String acceptLanguage,
    LatLng center,
    double radiusKm,
  ) async {
    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'lat': center.latitude.toString(),
        'lon': center.longitude.toString(),
        'limit': '30',
        'lang': acceptLanguage.startsWith('ar') ? 'ar' : 'en',
      });

      final response = await _get(uri);
      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? const [];

      return features.map((feature) {
        final map = feature as Map<String, dynamic>;
        final geometry = map['geometry'] as Map<String, dynamic>;
        final coords = geometry['coordinates'] as List<dynamic>;
        final props = map['properties'] as Map<String, dynamic>? ?? const {};

        final name = props['name'] as String? ?? query;
        final city = props['city'] as String? ?? props['county'] as String? ?? '';
        final street = props['street'] as String? ?? '';
        final labelParts = [name, street, city].where((part) => part.isNotEmpty);

        return PlaceResult(
          label: labelParts.join(', '),
          latitude: (coords[1] as num).toDouble(),
          longitude: (coords[0] as num).toDouble(),
        );
      }).where((place) {
        final km = _distance.as(
          LengthUnit.Kilometer,
          center,
          LatLng(place.latitude, place.longitude),
        );
        return km <= radiusKm;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlaceResult>> _overpassSearch(
    String query,
    LatLng center,
    double radiusKm,
  ) async {
    try {
      final escaped = query.replaceAll('"', r'\"');
      final delta = radiusKm / 111.0;
      final south = center.latitude - delta;
      final north = center.latitude + delta;
      final west = center.longitude - delta;
      final east = center.longitude + delta;

      final categoryLines =
          _overpassCategoryLines(south, west, north, east, query);
      final wordPattern = _overpassWordPattern(query);

      final overpass = '''
[out:json][timeout:12];
(
  nwr["name"~"$escaped",i]($south,$west,$north,$east);
  nwr["name:ar"~"$escaped",i]($south,$west,$north,$east);
${wordPattern.isEmpty ? '' : '  nwr["name"~"$wordPattern",i]($south,$west,$north,$east);\n  nwr["name:ar"~"$wordPattern",i]($south,$west,$north,$east);'}
${categoryLines.join('\n')}
);
out center 30;
''';

      return await _runOverpassQuery(overpass);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PlaceResult>> _overpassCategorySearch(
    String query,
    LatLng center,
    double radiusKm,
  ) async {
    final delta = radiusKm / 111.0;
    final south = center.latitude - delta;
    final north = center.latitude + delta;
    final west = center.longitude - delta;
    final east = center.longitude + delta;

    final lines = _overpassCategoryLines(south, west, north, east, query);
    if (lines.isEmpty) return const [];

    final overpass = '''
[out:json][timeout:12];
(
${lines.join('\n')}
);
out center 40;
''';
    return _runOverpassQuery(overpass);
  }

  Future<List<PlaceResult>> _runOverpassQuery(String overpass) async {
    for (final endpoint in const [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
    ]) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              body: {'data': overpass},
            )
            .timeout(_overpassTimeout);

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? const [];

        return elements.map((element) {
          final map = element as Map<String, dynamic>;
          final tags = map['tags'] as Map<String, dynamic>? ?? const {};
          final lat = (map['lat'] as num?)?.toDouble() ??
              ((map['center'] as Map<String, dynamic>?)?['lat'] as num?)
                  ?.toDouble();
          final lon = (map['lon'] as num?)?.toDouble() ??
              ((map['center'] as Map<String, dynamic>?)?['lon'] as num?)
                  ?.toDouble();

          if (lat == null || lon == null) return null;

          return PlaceResult(
            label: _osmPlaceLabel(tags),
            latitude: lat,
            longitude: lon,
          );
        }).whereType<PlaceResult>().toList();
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  String _osmPlaceLabel(Map<String, dynamic> tags) {
    final nameAr = tags['name:ar'] as String?;
    if (nameAr != null && nameAr.trim().isNotEmpty) return nameAr.trim();

    final name = tags['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();

    final shop = tags['shop'] as String?;
    if (shop != null) return _osmTagLabelAr(shop);

    final amenity = tags['amenity'] as String?;
    if (amenity != null) return _osmTagLabelAr(amenity);

    return 'مكان';
  }

  String _osmTagLabelAr(String tag) {
    const labels = {
      'supermarket': 'سوبرماركت',
      'convenience': 'بقالة',
      'general': 'محل',
      'grocery': 'بقالة',
      'mall': 'مجمع تجاري',
      'department_store': 'متجر',
      'car': 'معرض سيارات',
      'car_repair': 'ورشة سيارات',
      'car_dealer': 'معرض سيارات',
      'trade': 'معرض',
      'restaurant': 'مطعم',
      'cafe': 'مقهى',
      'fast_food': 'وجبات سريعة',
      'pharmacy': 'صيدلية',
      'chemist': 'صيدلية',
      'bank': 'بنك',
      'atm': 'صراف آلي',
      'fuel': 'محطة وقود',
      'hospital': 'مستشفى',
      'clinic': 'عيادة',
      'school': 'مدرسة',
      'university': 'جامعة',
      'college': 'كلية',
      'place_of_worship': 'مسجد',
      'marketplace': 'سوق',
    };
    return labels[tag] ?? tag;
  }

  String _overpassWordPattern(String query) {
    final words = query
        .trim()
        .split(RegExp(r'[\s,،]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 2)
        .map((w) => w.replaceAll('"', ''))
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words.first;
    return words.join('|');
  }

  List<String> _overpassCategoryLines(
    double south,
    double west,
    double north,
    double east,
    String query,
  ) {
    final q = _normalizeArabicQuery(query.trim().toLowerCase());
    final lines = <String>[];
    final bbox = '($south,$west,$north,$east)';

    void add(String line) {
      if (!lines.contains(line)) lines.add('  $line');
    }

    bool matches(List<String> needles) =>
        needles.any((needle) => q.contains(_normalizeArabicQuery(needle)));

    if (matches([
      'سوبر',
      'ماركت',
      'supermarket',
      'grocery',
      'بقال',
      'هايبر',
      'market',
    ])) {
      add(
        'nwr["shop"~"supermarket|convenience|general|grocery|department_store|mall"]$bbox;',
      );
    }
    if (matches([
      'سيار',
      'معرض',
      'car',
      'dealer',
      'vehicle',
      'motors',
      'بيع',
    ])) {
      add('nwr["shop"~"car|car_repair|trade|tyres|motorcycle"]$bbox;');
      add('nwr["amenity"="car_dealer"]$bbox;');
    }
    if (matches(['مطعم', 'restaurant', 'food', 'كاف', 'cafe', 'وجبات'])) {
      add('nwr["amenity"~"restaurant|cafe|fast_food|food_court"]$bbox;');
    }
    if (matches(['صيدل', 'pharmacy', 'drug', 'دواء'])) {
      add('nwr["amenity"="pharmacy"]$bbox;');
      add('nwr["shop"="chemist"]$bbox;');
    }
    if (matches(['بنك', 'bank', 'atm', 'صراف'])) {
      add('nwr["amenity"~"bank|atm"]$bbox;');
    }
    if (matches(['مدرس', 'school', 'روض'])) {
      add('nwr["amenity"~"school|kindergarten"]$bbox;');
    }
    if (matches(['جامع', 'university', 'college', 'كلية'])) {
      add('nwr["amenity"~"university|college"]$bbox;');
    }
    if (matches(['محطة', 'وقود', 'fuel', 'gas', 'petrol', 'بنزين'])) {
      add('nwr["amenity"="fuel"]$bbox;');
    }
    if (matches(['مسجد', 'mosque', 'جامع'])) {
      add('nwr["amenity"="place_of_worship"]["religion"="muslim"]$bbox;');
    }
    if (matches(['مستشف', 'hospital', 'clinic', 'عياد', 'طب'])) {
      add('nwr["amenity"~"hospital|clinic|doctors"]$bbox;');
    }
    if (matches(['سوق', 'shop', 'store', 'محل', 'تجار'])) {
      add('nwr["shop"]$bbox;');
      add('nwr["amenity"="marketplace"]$bbox;');
    }

    return lines;
  }

  String _normalizeArabicQuery(String value) {
    return value
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  Future<List<PlaceResult>> _nominatimSearch(
    String query,
    String acceptLanguage,
    LatLng center,
    double radiusKm,
    String regionLabel,
  ) async {
    final usesArabic =
        acceptLanguage.startsWith('ar') || _arabicScript.hasMatch(query);
    final searchQuery = usesArabic
        ? '$query, $regionLabel, بابل, العراق'
        : '$query, $regionLabel, Babil, Iraq';
    final delta = radiusKm / 111.0;

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': searchQuery,
        'format': 'json',
        'limit': '25',
        'countrycodes': 'iq',
        'addressdetails': '1',
        'viewbox':
            '${center.longitude - delta},${center.latitude + delta},'
            '${center.longitude + delta},${center.latitude - delta}',
        'bounded': '0',
      });

      final response = await _get(
        uri,
        headers: {
          'User-Agent': 'HelloTukTuk/1.0 (com.hillaride.hilla_ride)',
          'Accept-Language': acceptLanguage.startsWith('ar') ? 'ar,en' : 'en,ar',
        },
      );

      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body);
      if (data is! List<dynamic>) {
        return const [];
      }

      return data.map((item) {
        final map = item as Map<String, dynamic>;
        return PlaceResult(
          label: map['display_name'] as String? ?? searchQuery,
          latitude: double.parse(map['lat'] as String),
          longitude: double.parse(map['lon'] as String),
        );
      }).where((place) {
        final km = _distance.as(
          LengthUnit.Kilometer,
          center,
          LatLng(place.latitude, place.longitude),
        );
        return km <= radiusKm;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<PlaceResult> _mergeResultsInRegion({
    required RegionSearchContext region,
    required List<List<PlaceResult>> groups,
    bool allowDistrictFallback = false,
  }) {
    final merged = _mergeWithBounds(
      region: region,
      groups: groups,
      useDistrictBounds: false,
    );

    if (merged.isNotEmpty || !allowDistrictFallback) {
      return merged;
    }

    return _mergeWithBounds(
      region: region,
      groups: groups,
      useDistrictBounds: true,
    );
  }

  List<PlaceResult> _mergeWithBounds({
    required RegionSearchContext region,
    required List<List<PlaceResult>> groups,
    required bool useDistrictBounds,
  }) {
    final seen = <String>{};
    final merged = <PlaceResult>[];

    for (final group in groups) {
      for (final place in group) {
        final point = LatLng(place.latitude, place.longitude);
        final inBounds = useDistrictBounds || !region.hasSubDistrict
            ? BabilRegions.isWithinDistrict(region.districtId, point)
            : BabilRegions.isWithinSubDistrict(
                region.districtId,
                region.subDistrictId!,
                point,
              );
        if (!inBounds) {
          continue;
        }

        final key =
            '${place.latitude.toStringAsFixed(4)},${place.longitude.toStringAsFixed(4)}';
        if (seen.add(key)) {
          merged.add(place);
        }
        if (merged.length >= _maxResults) {
          return merged;
        }
      }
    }

    return merged;
  }

  Future<String> reverseGeocode(
    LatLng point, {
    String acceptLanguage = 'en',
    RegionSearchContext? region,
    bool preferStreet = false,
  }) async {
    if (region != null &&
        region.hasSubDistrict &&
        !BabilRegions.isWithinSubDistrict(
          region.districtId,
          region.subDistrictId!,
          point,
        )) {
      if (!preferStreet) {
        return region.label(isArabic: acceptLanguage.startsWith('ar'));
      }
    }

    final languageCode = acceptLanguage.startsWith('ar') ? 'ar' : 'en';
    final isArabic = languageCode == 'ar';

    if (kIsWeb && MapsConfig.useGooglePlacesHttp) {
      try {
        final webLabel = await fetchWebReverseGeocode(
          point,
          languageCode: languageCode,
        ).timeout(const Duration(seconds: 10));
        if (webLabel != null &&
            !_looksLikeCoordinateLabel(webLabel) &&
            _isAcceptablePinLabel(webLabel, region, preferStreet: preferStreet)) {
          return webLabel;
        }
      } catch (error) {
        if (kDebugMode) debugPrint('Web reverse geocode failed: $error');
      }

      final webRestStreet = await _fetchGoogleStreetLabel(
        point,
        languageCode: languageCode,
        isArabic: isArabic,
      );
      if (webRestStreet != null &&
          !_looksLikeCoordinateLabel(webRestStreet) &&
          _isAcceptablePinLabel(
            webRestStreet,
            region,
            preferStreet: preferStreet,
          )) {
        return webRestStreet;
      }
    } else if (MapsConfig.useGooglePlacesHttp && !_googlePlaces.isApiDenied) {
      final googleStreet = await _fetchGoogleStreetLabel(
        point,
        languageCode: languageCode,
        isArabic: isArabic,
      );
      if (googleStreet != null &&
          !_looksLikeCoordinateLabel(googleStreet) &&
          _isAcceptablePinLabel(
            googleStreet,
            region,
            preferStreet: preferStreet,
          )) {
        return googleStreet;
      }
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': point.latitude.toString(),
        'lon': point.longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
        'accept-language': acceptLanguage.startsWith('ar') ? 'ar,en' : 'en,ar',
      });

      final response = await _get(
        uri,
        headers: {
          'User-Agent': 'HelloTukTuk/1.0 (com.hillaride.hilla_ride)',
          'Accept-Language': acceptLanguage.startsWith('ar') ? 'ar,en' : 'en,ar',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final streetLabel = StreetAddressFormatter.fromNominatimAddress(
          data['address'] as Map<String, dynamic>?,
        );
        if (streetLabel != null &&
            streetLabel.isNotEmpty &&
            _isAcceptablePinLabel(
              streetLabel,
              region,
              preferStreet: preferStreet,
            )) {
          return streetLabel;
        }
        final name = data['display_name'] as String?;
        final formatted = StreetAddressFormatter.firstStreetLikeSegment(
          name,
          isArabic: isArabic,
        );
        if (formatted != null &&
            formatted.isNotEmpty &&
            _isAcceptablePinLabel(
              formatted,
              region,
              preferStreet: preferStreet,
            )) {
          return formatted;
        }
      }
    } catch (_) {
      // Fall through to region label.
    }

    if (preferStreet) {
      return '';
    }

    if (region != null) {
      return region.label(isArabic: acceptLanguage.startsWith('ar'));
    }

    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  bool _isAcceptablePinLabel(
    String label,
    RegionSearchContext? region, {
    required bool preferStreet,
  }) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return false;
    if (!preferStreet) return true;
    if (StreetAddressFormatter.looksLikeStreetName(trimmed)) return true;
    if (region == null) return false;

    final sub = region.subDistrictOrNull;
    if (sub != null &&
        (trimmed == sub.nameAr ||
            trimmed == sub.nameEn ||
            trimmed.toLowerCase() == sub.nameEn.toLowerCase())) {
      return false;
    }

    final district = region.district;
    if (trimmed == district.nameAr ||
        trimmed == district.nameEn ||
        trimmed.toLowerCase() == district.nameEn.toLowerCase()) {
      return false;
    }

    return trimmed.contains('،') || trimmed.contains(',');
  }

  Future<String?> _fetchGoogleStreetLabel(
    LatLng point, {
    required String languageCode,
    required bool isArabic,
  }) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '${point.latitude},${point.longitude}',
        'key': MapsConfig.placesWebApiKey,
        'language': languageCode,
        'region': 'iq',
      });

      final response = await _get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      return StreetAddressFormatter.fromGoogleGeocodeResults(
        data['results'] as List<dynamic>?,
        isArabic: isArabic,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Google street reverse geocode failed: $error');
    }
    return null;
  }

  bool isWithinServiceArea(LatLng point) {
    final km = _distance.as(
      LengthUnit.Kilometer,
      HillaConstants.cityCenter,
      point,
    );
    return km <= HillaConstants.serviceRadiusKm;
  }

  bool get isGooglePlacesBlocked =>
      kIsWeb
          ? !_webGooglePlacesAvailable && _googlePlaces.isApiDenied
          : !_hasGooglePlacesSource;

  bool get isUsingGooglePlaces => _hasGooglePlacesSource;

  bool isWithinRegion(RegionSearchContext region, LatLng point) {
    if (!region.hasSubDistrict) {
      return BabilRegions.isWithinDistrict(region.districtId, point);
    }
    return BabilRegions.isWithinSubDistrict(
      region.districtId,
      region.subDistrictId!,
      point,
    );
  }
}
