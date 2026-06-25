import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/commission_config.dart';

class CommissionService {
  CommissionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _docPath = 'config/commission';

  Stream<CommissionConfig> watchConfig() {
    return _firestore.doc(_docPath).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return CommissionConfig.defaults;
      }
      return CommissionConfig.fromMap(snapshot.data());
    }).transform(
      StreamTransformer<CommissionConfig, CommissionConfig>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (kDebugMode) {
            debugPrint('Commission config listen failed, using defaults: $error');
          }
          sink.add(CommissionConfig.defaults);
        },
      ),
    );
  }

  CommissionConfig? _cachedConfig;
  DateTime? _cachedAt;

  Future<CommissionConfig> getConfig() async {
    final cached = _cachedConfig;
    final cachedAt = _cachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 30)) {
      return cached;
    }

    try {
      final snapshot = await _firestore.doc(_docPath).get();
      final config = !snapshot.exists || snapshot.data() == null
          ? CommissionConfig.defaults
          : CommissionConfig.fromMap(snapshot.data());
      _cachedConfig = config;
      _cachedAt = DateTime.now();
      return config;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Commission config read failed, using defaults: $error');
      }
      return _cachedConfig ?? CommissionConfig.defaults;
    }
  }

  Future<void> saveConfig(CommissionConfig config) async {
    await _firestore.doc(_docPath).set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  FareSplit splitFare(int fareIqd, double platformPercent) {
    final clampedPercent = platformPercent.clamp(0.0, 100.0);
    final commission = (fareIqd * clampedPercent / 100).round();
    return FareSplit(
      fareIqd: fareIqd,
      commissionPercent: clampedPercent,
      platformCommissionIqd: commission,
      driverEarningsIqd: fareIqd - commission,
    );
  }
}
