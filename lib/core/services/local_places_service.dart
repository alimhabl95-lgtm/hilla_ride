import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:latlong2/latlong.dart';

class LocalPlace {
  const LocalPlace({
    required this.nameEn,
    required this.nameAr,
    required this.keywords,
    required this.lat,
    required this.lon,
  });

  factory LocalPlace.fromJson(Map<String, dynamic> json) {
    return LocalPlace(
      nameEn: json['nameEn'] as String,
      nameAr: json['nameAr'] as String,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }

  final String nameEn;
  final String nameAr;
  final List<String> keywords;
  final double lat;
  final double lon;

  PlaceResult toPlaceResult({required bool preferArabic}) {
    return PlaceResult(
      label: preferArabic ? nameAr : nameEn,
      latitude: lat,
      longitude: lon,
    );
  }
}

class LocalPlacesService {
  LocalPlacesService();

  List<LocalPlace>? _places;
  Future<List<LocalPlace>>? _loadFuture;

  Future<List<LocalPlace>> _ensureLoaded() {
    return _loadFuture ??= _loadPlaces();
  }

  Future<List<LocalPlace>> _loadPlaces() async {
    final raw = await rootBundle.loadString('assets/data/hilla_places.json');
    final data = jsonDecode(raw) as List<dynamic>;
    _places = data
        .map((item) => LocalPlace.fromJson(item as Map<String, dynamic>))
        .toList();
    return _places!;
  }

  Future<List<PlaceResult>> listAll({bool preferArabic = true}) async {
    final places = await _ensureLoaded();
    return places
        .map((place) => place.toPlaceResult(preferArabic: preferArabic))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<List<PlaceResult>> filter(String query, {bool preferArabic = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return listAll(preferArabic: preferArabic);
    }
    return search(trimmed, acceptLanguage: preferArabic ? 'ar' : 'en');
  }

  Future<List<PlaceResult>> search(String query, {String acceptLanguage = 'en'}) async {
    final trimmed = query.trim();
    final minLength = _arabicScript.hasMatch(trimmed) ? 1 : 2;
    if (trimmed.length < minLength) {
      return const [];
    }

    final normalizedQuery = _normalize(trimmed);

    final places = await _ensureLoaded();
    final preferArabic = acceptLanguage.startsWith('ar');
    final scored = <({LocalPlace place, int score})>[];

    for (final place in places) {
      final score = _scorePlace(place, normalizedQuery);
      if (score > 0) {
        scored.add((place: place, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored
        .take(8)
        .map((entry) => entry.place.toPlaceResult(preferArabic: preferArabic))
        .toList();
  }

  int _scorePlace(LocalPlace place, String query) {
    var score = 0;
    final names = [
      _normalize(place.nameEn),
      _normalize(place.nameAr),
      ...place.keywords.map(_normalize),
    ];

    for (final name in names) {
      if (_normalize(name) == query) {
        score = maxScore(score, 100);
      } else if (_normalize(name).startsWith(query)) {
        score = maxScore(score, 80);
      } else if (query.startsWith(_normalize(name)) && name.length >= 2) {
        score = maxScore(score, 70);
      } else if (_containsIgnoreCase(name, query)) {
        score = maxScore(score, 60);
      }
    }

    return score;
  }

  int maxScore(int current, int candidate) => candidate > current ? candidate : current;

  String _normalize(String value) {
    return value
        .trim()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  bool _containsIgnoreCase(String haystack, String needle) {
    if (_arabicScript.hasMatch(needle)) {
      return _normalize(haystack).contains(_normalize(needle));
    }
    return haystack.toLowerCase().contains(needle.toLowerCase());
  }

  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');

  bool isWithinServiceArea(double lat, double lon) {
    const distance = Distance();
    final km = distance.as(
      LengthUnit.Kilometer,
      HillaConstants.cityCenter,
      LatLng(lat, lon),
    );
    return km <= HillaConstants.serviceRadiusKm;
  }
}
