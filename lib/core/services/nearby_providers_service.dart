import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:hilla_ride/core/models/map_presence.dart';
import 'package:hilla_ride/core/utils/geohash.dart';
import 'package:latlong2/latlong.dart';

/// Watches nearby available providers on the customer map (ride + future services).
class NearbyProvidersService {
  NearbyProvidersService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _distance = Distance();

  /// Live stream of available providers near [center], capped and radius-filtered.
  Stream<List<MapPresence>> watchNearbyAvailable({
    required LatLng center,
    String serviceType = MapPresenceConfig.serviceTypeRide,
    double radiusKm = MapPresenceConfig.nearbyRadiusKm,
    int maxMarkers = MapPresenceConfig.maxNearbyMarkers,
  }) {
    final prefixes = Geohash.searchPrefixes(center.latitude, center.longitude);
    final controller = StreamController<List<MapPresence>>();
    final latestByPrefix = <String, List<MapPresence>>{};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emitMerged() {
      final seen = <String>{};
      final merged = <MapPresence>[];
      for (final list in latestByPrefix.values) {
        for (final item in list) {
          if (!seen.add(item.providerId)) continue;
          if (item.serviceType != serviceType) continue;
          if (!item.isVisibleOnCustomerMap) continue;
          final km = _distance.as(LengthUnit.Kilometer, center, item.latLng);
          if (km > radiusKm) continue;
          merged.add(item);
        }
      }
      merged.sort((a, b) {
        final da = _distance.as(LengthUnit.Kilometer, center, a.latLng);
        final db = _distance.as(LengthUnit.Kilometer, center, b.latLng);
        return da.compareTo(db);
      });
      if (!controller.isClosed) {
        controller.add(merged.take(maxMarkers).toList(growable: false));
      }
    }

    for (final prefix in prefixes) {
      final query = _firestore
          .collection(MapPresenceConfig.collection)
          .where('serviceType', isEqualTo: serviceType)
          .where('status', isEqualTo: DriverOperationalStatus.available.value)
          .where('geohash', isGreaterThanOrEqualTo: prefix)
          .where('geohash', isLessThanOrEqualTo: Geohash.upperBound(prefix))
          .limit(24);

      subs.add(
        query.snapshots().listen(
          (snapshot) {
            latestByPrefix[prefix] = snapshot.docs
                .map((doc) => MapPresence.fromMap(doc.id, doc.data()))
                .toList();
            emitMerged();
          },
          onError: controller.addError,
        ),
      );
    }

    controller.onCancel = () async {
      for (final sub in subs) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  /// Haversine helper for ETA display when Directions is unavailable.
  static double straightLineKm(LatLng a, LatLng b) {
    return _distance.as(LengthUnit.Kilometer, a, b);
  }

  static int estimateMinutes(double distanceKm, {double speedKmh = 22}) {
    if (distanceKm <= 0) return 1;
    return math.max(1, (distanceKm / speedKmh * 60).round());
  }
}
