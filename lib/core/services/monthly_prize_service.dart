import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/promo_models.dart';

class MonthlyPrizeService {
  MonthlyPrizeService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  static const _configDoc = 'config/monthly_prize';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.doc(_configDoc);

  Stream<MonthlyPrizeConfig> watchConfig() {
    return _configRef.snapshots().map(
          (snapshot) => MonthlyPrizeConfig.fromMap(snapshot.data()),
        );
  }

  Future<MonthlyPrizeConfig> getConfig() async {
    try {
      final snapshot = await _configRef.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return MonthlyPrizeConfig(
          prizeAmountIqd: MonthlyPrizeConfig.defaultPrizeIqd,
          monthKey: MonthlyPrizeConfig.currentMonthKey(),
        );
      }
      return MonthlyPrizeConfig.fromMap(snapshot.data());
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return MonthlyPrizeConfig(
          prizeAmountIqd: MonthlyPrizeConfig.defaultPrizeIqd,
          monthKey: MonthlyPrizeConfig.currentMonthKey(),
        );
      }
      rethrow;
    }
  }

  Future<void> savePrizeAmount(int prizeAmountIqd) async {
    await _configRef.set(
      {
        'prizeAmountIqd': prizeAmountIqd,
        'monthKey': MonthlyPrizeConfig.currentMonthKey(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<MonthlyLeaderboardEntry>> watchLeaderboard() {
    return _firestore.collection('drivers').snapshots().asyncMap(
      (snapshot) async {
        final config = await getConfig();
        return _buildLeaderboard(snapshot.docs, config);
      },
    );
  }

  Stream<DriverMonthlyStats> watchDriverStats(String driverId) {
    return _firestore.collection('drivers').snapshots().asyncMap(
      (snapshot) async {
        final config = await getConfig();
        final entries = _buildLeaderboard(snapshot.docs, config);
        final entry =
            entries.where((item) => item.driverId == driverId).firstOrNull;

        final driverDoc =
            snapshot.docs.where((doc) => doc.id == driverId).firstOrNull;
        var rideCount = entry?.rideCount ?? 0;
        if (rideCount == 0 && driverDoc != null) {
          final data = driverDoc.data();
          final monthKey = data['monthlyMonthKey'] as String? ?? '';
          if (monthKey == config.monthKey) {
            rideCount = (data['monthlyRideCount'] as num?)?.toInt() ?? 0;
          }
        }

        return DriverMonthlyStats(
          rideCount: rideCount,
          rank: entry?.rank ?? (entries.isEmpty ? 1 : entries.length + 1),
          totalDrivers: entries.length,
          prizeAmountIqd: config.prizeAmountIqd,
          monthKey: config.monthKey,
        );
      },
    );
  }

  List<MonthlyLeaderboardEntry> _buildLeaderboard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    MonthlyPrizeConfig config,
  ) {
    final monthKey = config.monthKey;
    final rows = <MonthlyLeaderboardEntry>[];

    for (final doc in docs) {
      final driver = DriverProfile.fromMap(doc.id, doc.data());
      if (driver.isRemoved || !driver.isApproved) continue;
      if (driver.monthlyMonthKey != monthKey) continue;
      if (driver.monthlyRideCount <= 0) continue;

      rows.add(
        MonthlyLeaderboardEntry(
          driverId: driver.uid,
          name: driver.name,
          phone: driver.phone,
          rideCount: driver.monthlyRideCount,
          rank: 0,
          isWinner: config.winnerDriverId == driver.uid,
          isPaid: config.winnerPaid && config.winnerDriverId == driver.uid,
        ),
      );
    }

    rows.sort((a, b) {
      final countCompare = b.rideCount.compareTo(a.rideCount);
      if (countCompare != 0) return countCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return [
      for (var i = 0; i < rows.length; i++)
        MonthlyLeaderboardEntry(
          driverId: rows[i].driverId,
          name: rows[i].name,
          phone: rows[i].phone,
          rideCount: rows[i].rideCount,
          rank: i + 1,
          isWinner: config.winnerDriverId == rows[i].driverId,
          isPaid: config.winnerPaid && config.winnerDriverId == rows[i].driverId,
        ),
    ];
  }

  Future<void> incrementDriverMonthlyRide(String driverId) async {
    if (driverId.isEmpty) return;

    final monthKey = MonthlyPrizeConfig.currentMonthKey();
    final ref = _firestore.collection('drivers').doc(driverId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) return;

    final currentKey = data['monthlyMonthKey'] as String? ?? '';
    if (currentKey != monthKey) {
      await ref.update({
        'monthlyMonthKey': monthKey,
        'monthlyRideCount': 1,
      });
      return;
    }

    await ref.update({
      'monthlyRideCount': FieldValue.increment(1),
    });
  }

  Future<void> _resetMonthlyCounterDirect() async {
    final monthKey = MonthlyPrizeConfig.currentMonthKey();
    final snapshot = await _firestore.collection('drivers').get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'monthlyRideCount': 0,
        'monthlyMonthKey': monthKey,
      });
    }

    batch.set(
      _configRef,
      {
        'monthKey': monthKey,
        'winnerDriverId': '',
        'winnerPaid': false,
        'resetAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  Future<void> _callAdminAction(String action, {String? driverId}) async {
    Future<void> writeDirect() async {
      if (action == 'markWinner' && driverId != null) {
        await _configRef.set(
          {
            'winnerDriverId': driverId,
            'winnerPaid': false,
            'winnerMarkedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      if (action == 'markPaid') {
        await _configRef.set(
          {
            'winnerPaid': true,
            'winnerPaidAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      if (action == 'reset') {
        await _resetMonthlyCounterDirect();
      }
    }

    try {
      await writeDirect();
      return;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      if (kDebugMode) {
        debugPrint(
          'Monthly prize Firestore write denied, trying adminMonthlyPrize function.',
        );
      }
    }

    try {
      final callable = _functions.httpsCallable('adminMonthlyPrize');
      await callable.call({
        'action': action,
        if (driverId != null) 'driverId': driverId,
      });
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'adminMonthlyPrize function failed: ${error.code} ${error.message}',
        );
      }
      rethrow;
    }
  }

  Future<void> markWinner(String driverId) async {
    await _callAdminAction('markWinner', driverId: driverId);
  }

  Future<void> markPaid() async {
    await _callAdminAction('markPaid');
  }

  Future<void> resetMonthlyCounter() async {
    try {
      await _resetMonthlyCounterDirect();
      return;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    try {
      final callable = _functions.httpsCallable('adminMonthlyPrize');
      await callable.call({'action': 'reset'});
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'adminMonthlyPrize reset failed: ${error.code} ${error.message}',
        );
      }
      rethrow;
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
