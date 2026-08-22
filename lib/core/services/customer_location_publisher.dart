import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';

/// Publishes the customer's GPS to `users/{uid}` during an active ride so the
/// driver can see them live on the map.
class CustomerLocationPublisher {
  CustomerLocationPublisher({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  StreamSubscription<Position>? _sub;
  String? _userId;
  DateTime? _lastWriteAt;
  Position? _lastWritten;

  Future<void> start(String userId) async {
    if (_userId == userId && _sub != null) return;
    await stop();
    _userId = userId;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;

    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: MapPresenceConfig.locationPublishMinMoveMeters.round(),
      ),
    ).listen(_publish);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _userId = null;
    _lastWriteAt = null;
    _lastWritten = null;
  }

  Future<void> _publish(Position position) async {
    final userId = _userId;
    if (userId == null) return;

    final now = DateTime.now();
    final lastWriteAt = _lastWriteAt;
    final lastWritten = _lastWritten;
    if (lastWriteAt != null &&
        now.difference(lastWriteAt) <
            MapPresenceConfig.locationPublishMinInterval &&
        lastWritten != null) {
      final moved = Geolocator.distanceBetween(
        lastWritten.latitude,
        lastWritten.longitude,
        position.latitude,
        position.longitude,
      );
      if (moved < MapPresenceConfig.locationPublishMinMoveMeters) {
        return;
      }
    }

    _lastWriteAt = now;
    _lastWritten = position;
    try {
      await _firestore.collection('users').doc(userId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
