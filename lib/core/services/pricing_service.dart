import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/pricing_config.dart';
import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:latlong2/latlong.dart';

class PricingService {
  PricingService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    DrivingDistanceService? drivingDistanceService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _drivingDistanceService =
            drivingDistanceService ?? DrivingDistanceService();

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final DrivingDistanceService _drivingDistanceService;
  static const _legacyDocPath = 'config/pricing';
  static const _legacySubcollection = 'cities';
  final Map<String, PricingConfig> _configCache = {};

  String _configCacheKey(String districtId, String? subDistrictId) {
    final sub = subDistrictId?.trim();
    return '${districtId.trim()}|${sub ?? ''}';
  }

  void prefetchConfig({
    required String districtId,
    String? subDistrictId,
  }) {
    unawaited(
      getConfig(
        districtId: districtId,
        subDistrictId: subDistrictId,
        preferServer: false,
      ),
    );
  }

  RideQuote quickQuote({
    required LatLng pickup,
    required LatLng destination,
    required String districtId,
    String? subDistrictId,
    PricingConfig? config,
  }) {
    if (!RideLocationRules.areDistinct(pickup, destination)) {
      return const RideQuote(
        distanceKm: 0,
        durationMinutes: 0,
        outOfService: true,
      );
    }

    final pricingConfig = config ??
        _configCache[_configCacheKey(districtId, subDistrictId)] ??
        PricingConfig.defaults;
    final route = _drivingDistanceService.estimateRouteSync(pickup, destination);
    final quote = quoteFromDistanceKm(route.distanceKm, pricingConfig);
    if (quote.outOfService) {
      return RideQuote(
        distanceKm: route.distanceKm,
        durationMinutes: route.durationMinutes,
        outOfService: true,
        isEstimatedDistance: true,
      );
    }
    return RideQuote(
      distanceKm: route.distanceKm,
      durationMinutes: route.durationMinutes,
      fareIqd: quote.fareIqd,
      isEstimatedDistance: true,
    );
  }

  String _districtDocId(String districtId) => 'pricing_$districtId';

  String _subDistrictDocId(String districtId, String subDistrictId) =>
      'pricing_${districtId}_$subDistrictId';

  DocumentReference<Map<String, dynamic>> _districtDocRef(String districtId) {
    final id = districtId.trim();
    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError.value(
        districtId,
        'districtId',
        'must be a non-empty document id',
      );
    }
    return _firestore.collection('config').doc(_districtDocId(id));
  }

  DocumentReference<Map<String, dynamic>> _subDistrictDocRef(
    String districtId,
    String subDistrictId,
  ) {
    final district = districtId.trim();
    final sub = subDistrictId.trim();
    if (district.isEmpty ||
        sub.isEmpty ||
        district.contains('/') ||
        sub.contains('/')) {
      throw ArgumentError(
        'districtId and subDistrictId must be non-empty document ids',
      );
    }
    return _firestore
        .collection('config')
        .doc(_subDistrictDocId(district, sub));
  }

  DocumentReference<Map<String, dynamic>> _pricingDocRef({
    required String districtId,
    String? subDistrictId,
  }) {
    final sub = subDistrictId?.trim();
    if (sub != null && sub.isNotEmpty) {
      return _subDistrictDocRef(districtId, sub);
    }
    return _districtDocRef(districtId);
  }

  DocumentReference<Map<String, dynamic>> _legacyCityDocRef(String districtId) {
    return _firestore
        .collection('config')
        .doc('pricing')
        .collection(_legacySubcollection)
        .doc(districtId.trim());
  }

  Stream<PricingConfig> watchConfig({
    required String districtId,
    String? subDistrictId,
  }) {
    late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> subscription;
    final controller = StreamController<PricingConfig>();
    var disposed = false;

    Future<void> emitResolvedConfig() async {
      if (disposed || controller.isClosed) return;
      controller.add(
        await getConfig(
          districtId: districtId,
          subDistrictId: subDistrictId,
          preferServer: false,
        ),
      );
    }

    emitResolvedConfig();

    subscription = _pricingDocRef(
      districtId: districtId,
      subDistrictId: subDistrictId,
    ).snapshots().listen(
      (snapshot) {
        if (disposed || controller.isClosed) return;
        if (snapshot.exists && snapshot.data() != null) {
          controller.add(PricingConfig.fromMap(snapshot.data()!));
          return;
        }
        emitResolvedConfig();
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint(
            'Pricing watch error for $districtId/${subDistrictId ?? 'district'}: $error',
          );
        }
        emitResolvedConfig();
      },
    );

    controller.onCancel = () async {
      disposed = true;
      await subscription.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  Future<PricingConfig?> _readDoc(
    DocumentReference<Map<String, dynamic>> ref, {
    bool preferServer = false,
  }) async {
    try {
      if (preferServer) {
        try {
          final snapshot = await ref.get(const GetOptions(source: Source.server));
          if (snapshot.exists && snapshot.data() != null) {
            return PricingConfig.fromMap(snapshot.data()!);
          }
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Pricing server read failed for ${ref.path}: $error');
          }
        }
      }

      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.data() != null) {
        return PricingConfig.fromMap(snapshot.data()!);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Pricing read failed for ${ref.path}: $error');
      }
    }
    return null;
  }

  Future<PricingConfig> getConfig({
    required String districtId,
    String? subDistrictId,
    bool? preferServer,
  }) async {
    final cacheKey = _configCacheKey(districtId, subDistrictId);
    if (!((preferServer ?? !kIsWeb))) {
      final cached = _configCache[cacheKey];
      if (cached != null) return cached;
    }

    final useServer = preferServer ?? !kIsWeb;
    final sub = subDistrictId?.trim();
    final hasSubDistrict = sub != null && sub.isNotEmpty;

    try {
      final reads = <Future<PricingConfig?>>[
        if (hasSubDistrict)
          _readDoc(
            _subDistrictDocRef(districtId, sub),
            preferServer: useServer,
          ),
        _readDoc(
          _districtDocRef(districtId),
          preferServer: useServer,
        ),
        _readDoc(
          _legacyCityDocRef(districtId),
          preferServer: useServer,
        ),
      ];

      final results = await Future.wait(reads);
      var index = 0;
      if (hasSubDistrict) {
        final subConfig = results[index++];
        if (subConfig != null) {
          _configCache[cacheKey] = subConfig;
          return subConfig;
        }
      }

      final districtConfig = results[index++];
      if (districtConfig != null) {
        _configCache[cacheKey] = districtConfig;
        return districtConfig;
      }

      final legacyCityConfig = results[index];
      if (legacyCityConfig != null) {
        _configCache[cacheKey] = legacyCityConfig;
        return legacyCityConfig;
      }

      final legacySnapshot = await _firestore.doc(_legacyDocPath).get();
      if (legacySnapshot.exists && legacySnapshot.data() != null) {
        final legacyConfig = PricingConfig.fromMap(legacySnapshot.data()!);
        _configCache[cacheKey] = legacyConfig;
        return legacyConfig;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Pricing config read failed, using defaults: $error');
      }
    }

    _configCache[cacheKey] = PricingConfig.defaults;
    return PricingConfig.defaults;
  }

  Future<void> saveConfig({
    required String districtId,
    String? subDistrictId,
    required PricingConfig config,
  }) async {
    final sub = subDistrictId?.trim();
    final cacheKey = _configCacheKey(districtId, sub);
    final payload = {
      'districtId': districtId,
      if (sub != null && sub.isNotEmpty) 'subDistrictId': sub,
      'maxDistanceKm': config.maxDistanceKm,
      'brackets': config.brackets.map((b) => b.toMap()).toList(),
    };

    try {
      final callable = _functions.httpsCallable('savePricingConfig');
      await callable.call(payload);
      _configCache[cacheKey] = config;
      return;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        rethrow;
      }
      if (kDebugMode) {
        debugPrint(
          'savePricingConfig function failed (${error.code}): ${error.message}. '
          'Trying Firestore write.',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('savePricingConfig call failed: $error. Trying Firestore write.');
      }
    }

    final ref = _pricingDocRef(districtId: districtId, subDistrictId: sub);
    final firestorePayload = {
      ...config.toMap(),
      'districtId': districtId,
      if (sub != null && sub.isNotEmpty) 'subDistrictId': sub,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await ref.set(firestorePayload);

      final verify = await ref.get(const GetOptions(source: Source.server));
      if (!verify.exists || verify.data() == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Pricing was not saved to Firebase.',
        );
      }

      final saved = PricingConfig.fromMap(verify.data()!);
      if (saved.fingerprint != config.fingerprint && kDebugMode) {
        debugPrint(
          'Pricing verify mismatch. expected=${config.fingerprint} '
          'actual=${saved.fingerprint}',
        );
      }

      _configCache[cacheKey] = saved;
    } on FirebaseException catch (error) {
      if (kDebugMode) {
        debugPrint('Pricing config save failed: ${error.code} ${error.message}');
      }
      rethrow;
    }
  }

  RideQuote quoteFromDistanceKm(double distanceKm, PricingConfig config) {
    if (distanceKm > config.maxDistanceKm) {
      return RideQuote(
        distanceKm: distanceKm,
        durationMinutes: 0,
        outOfService: true,
      );
    }

    for (final bracket in config.brackets) {
      if (distanceKm >= bracket.minKm && distanceKm <= bracket.maxKm) {
        return RideQuote(
          distanceKm: distanceKm,
          durationMinutes: 0,
          fareIqd: bracket.priceIqd,
        );
      }
    }

    return RideQuote(
      distanceKm: distanceKm,
      durationMinutes: 0,
      outOfService: true,
    );
  }

  Future<RideQuote> quoteRide({
    required LatLng pickup,
    required LatLng destination,
    required String districtId,
    String? subDistrictId,
    PricingConfig? config,
    bool preferFastEstimate = false,
  }) async {
    if (!RideLocationRules.areDistinct(pickup, destination)) {
      return const RideQuote(
        distanceKm: 0,
        durationMinutes: 0,
        outOfService: true,
      );
    }

    final pricingConfig = config ??
        await getConfig(
          districtId: districtId,
          subDistrictId: subDistrictId,
        );

    if (preferFastEstimate) {
      return quickQuote(
        pickup: pickup,
        destination: destination,
        districtId: districtId,
        subDistrictId: subDistrictId,
        config: pricingConfig,
      );
    }

    final route = await _drivingDistanceService.getDrivingRoute(
      pickup,
      destination,
    );

    final quote = quoteFromDistanceKm(route.distanceKm, pricingConfig);
    if (quote.outOfService) {
      return RideQuote(
        distanceKm: route.distanceKm,
        durationMinutes: route.durationMinutes,
        outOfService: true,
        isEstimatedDistance: route.isEstimated,
      );
    }

    return RideQuote(
      distanceKm: route.distanceKm,
      durationMinutes: route.durationMinutes,
      fareIqd: quote.fareIqd,
      isEstimatedDistance: route.isEstimated,
    );
  }

  String formatIqd(int amount, {String locale = 'en'}) {
    return const FareService().formatIqd(amount, locale: locale);
  }
}
