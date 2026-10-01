import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/app_models.dart';

/// Completed/cancelled ride counts for the current calendar month (local time).
class DriverCalendarMonthStats {
  const DriverCalendarMonthStats({
    required this.completed,
    required this.cancelled,
    required this.monthKey,
    this.earningsIqd = 0,
  });

  final int completed;
  final int cancelled;
  final String monthKey;
  final int earningsIqd;

  static const zero = DriverCalendarMonthStats(
    completed: 0,
    cancelled: 0,
    monthKey: '',
  );
}

/// Completed/cancelled ride counts for today (local calendar day).
class DriverCalendarDayStats {
  const DriverCalendarDayStats({
    required this.completed,
    required this.cancelled,
    required this.dayKey,
  });

  final int completed;
  final int cancelled;
  final String dayKey;

  static const zero = DriverCalendarDayStats(
    completed: 0,
    cancelled: 0,
    dayKey: '',
  );
}

class DriverDashboardRideStats {
  const DriverDashboardRideStats({
    required this.todayCompleted,
    required this.todayCancelled,
    required this.monthCompleted,
    required this.monthCancelled,
    required this.monthEarningsIqd,
    required this.dayKey,
    required this.monthKey,
  });

  final int todayCompleted;
  final int todayCancelled;
  final int monthCompleted;
  final int monthCancelled;
  final int monthEarningsIqd;
  final String dayKey;
  final String monthKey;

  static const zero = DriverDashboardRideStats(
    todayCompleted: 0,
    todayCancelled: 0,
    monthCompleted: 0,
    monthCancelled: 0,
    monthEarningsIqd: 0,
    dayKey: '',
    monthKey: '',
  );

  DriverCalendarDayStats get today => DriverCalendarDayStats(
        completed: todayCompleted,
        cancelled: todayCancelled,
        dayKey: dayKey,
      );

  DriverCalendarMonthStats get month => DriverCalendarMonthStats(
        completed: monthCompleted,
        cancelled: monthCancelled,
        monthKey: monthKey,
        earningsIqd: monthEarningsIqd,
      );
}

class DriverMonthlyRideStatsService {
  DriverMonthlyRideStatsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, Stream<DriverDashboardRideStats>> _dashboardStreams = {};
  final Map<String, Stream<DriverCalendarDayStats>> _todayStreams = {};
  final Map<String, Stream<DriverCalendarMonthStats>> _monthStreams = {};
  final Map<String, void Function()> _dashboardEmitHooks = {};
  final Map<String, DriverDashboardRideStats> _latestStats = {};
  final Map<String, Map<String, DateTime>> _optimisticRejections = {};

  static String monthKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static String dayKeyFor(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static DateTime? _readTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate().toLocal();
    if (raw is DateTime) return raw.toLocal();
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt()).toLocal();
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  static bool _sameDay(DateTime time, DateTime now) {
    final local = time.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static bool _sameMonth(DateTime time, DateTime now) {
    final local = time.toLocal();
    return local.year == now.year && local.month == now.month;
  }

  static DateTime? _rejectionTime(Map<String, dynamic> data) {
    return _readTime(data['rejectedAtMillis']) ??
        _readTime(data['rejectedAt']);
  }

  static DateTime? _eventTime(
    Map<String, dynamic> data, {
    required bool completed,
  }) {
    final primary = completed ? 'completedAt' : 'cancelledAt';
    return _readTime(data[primary]) ??
        _readTime(data['updatedAt']) ??
        _readTime(data['createdAt']);
  }

  static int _rideEarningsIqd(Map<String, dynamic> data) {
    final net = (data['driverEarningsIqd'] as num?)?.toInt() ?? 0;
    if (net > 0) return net;
    final fare = (data['fareAmountIqd'] as num?)?.toInt() ?? 0;
    final commission = (data['platformCommissionIqd'] as num?)?.toInt() ?? 0;
    if (fare > commission && commission > 0) return fare - commission;
    return fare > 0 ? fare : 0;
  }

  void _pushOptimisticRejection({
    required String driverId,
    required String rideId,
    required DateTime at,
  }) {
    if (driverId.isEmpty || rideId.isEmpty) return;
    final bucket =
        _optimisticRejections.putIfAbsent(driverId, () => <String, DateTime>{});
    bucket[rideId] = at;
    _dashboardEmitHooks[driverId]?.call();
  }

  /// Saves this driver's rejection so cancelled counts can be queried from it.
  Future<void> recordRejection({
    required String driverId,
    required String rideId,
  }) async {
    if (driverId.isEmpty || rideId.isEmpty) return;
    final now = DateTime.now();
    _pushOptimisticRejection(driverId: driverId, rideId: rideId, at: now);

    final payload = <String, dynamic>{
      'rideId': rideId,
      'driverId': driverId,
      'rejectedAt': Timestamp.fromDate(now),
      'rejectedAtMillis': now.millisecondsSinceEpoch,
    };

    try {
      await _firestore
          .collection('drivers')
          .doc(driverId)
          .collection('rideRejections')
          .doc(rideId)
          .set(payload, SetOptions(merge: true));
    } catch (error) {
      debugPrint('recordRejection doc failed: $error');
    }

    try {
      await _firestore
          .collection('driverRideRejections')
          .doc('${rideId}_$driverId')
          .set(payload, SetOptions(merge: true));
    } catch (error) {
      debugPrint('recordRejection root failed: $error');
    }
  }

  Stream<DriverDashboardRideStats> watchDashboardRideStats(String driverId) {
    if (driverId.isEmpty) {
      return Stream.value(DriverDashboardRideStats.zero);
    }
    return _dashboardStreams.putIfAbsent(
      driverId,
      () => _buildDashboardStatsStream(driverId),
    );
  }

  Stream<DriverCalendarDayStats> watchTodayStats(String driverId) {
    return _todayStreams.putIfAbsent(
      driverId,
      () => watchDashboardRideStats(driverId).map((stats) => stats.today),
    );
  }

  Stream<DriverCalendarMonthStats> watchCalendarMonthStats(String driverId) {
    return _monthStreams.putIfAbsent(
      driverId,
      () => watchDashboardRideStats(driverId).map((stats) => stats.month),
    );
  }

  Stream<DriverDashboardRideStats> _buildDashboardStatsStream(String driverId) {
    late final StreamController<DriverDashboardRideStats> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ridesSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? rejectionSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? rootRejectionSub;
    QuerySnapshot<Map<String, dynamic>>? ridesSnap;
    QuerySnapshot<Map<String, dynamic>>? rejectionSnap;
    QuerySnapshot<Map<String, dynamic>>? rootRejectionSnap;

    void emit() {
      if (controller.isClosed) return;
      final now = DateTime.now();
      var todayCompleted = 0;
      var monthCompleted = 0;
      var todayCancelled = 0;
      var monthCancelled = 0;
      var monthEarnings = 0;
      final countedCancelled = <String>{};

      if (ridesSnap != null) {
        for (final doc in ridesSnap!.docs) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          final completed = status == RideStatus.completed.value ||
              data['earningsApplied'] == true;
          if (completed && status != RideStatus.cancelled.value) {
            final at = _eventTime(data, completed: true);
            if (at == null) continue;
            if (_sameDay(at, now)) todayCompleted++;
            if (_sameMonth(at, now)) {
              monthCompleted++;
              monthEarnings += _rideEarningsIqd(data);
            }
            continue;
          }
          if (status != RideStatus.cancelled.value) continue;
          final at = _eventTime(data, completed: false);
          if (at == null) continue;
          countedCancelled.add(doc.id);
          if (_sameDay(at, now)) todayCancelled++;
          if (_sameMonth(at, now)) monthCancelled++;
        }
      }

      void countRejection(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        final data = doc.data();
        final rideId = (data['rideId'] as String?)?.trim().isNotEmpty == true
            ? (data['rideId'] as String).trim()
            : doc.id;
        if (rideId.isEmpty || countedCancelled.contains(rideId)) return;
        final at = _rejectionTime(data);
        if (at == null) return;
        countedCancelled.add(rideId);
        if (_sameDay(at, now)) todayCancelled++;
        if (_sameMonth(at, now)) monthCancelled++;
      }

      if (rejectionSnap != null) {
        for (final doc in rejectionSnap!.docs) {
          countRejection(doc);
        }
      }
      if (rootRejectionSnap != null) {
        for (final doc in rootRejectionSnap!.docs) {
          countRejection(doc);
        }
      }

      final optimistic = _optimisticRejections[driverId];
      optimistic?.removeWhere((rideId, _) => countedCancelled.contains(rideId));
      if (optimistic != null) {
        for (final entry in optimistic.entries) {
          if (_sameDay(entry.value, now)) todayCancelled++;
          if (_sameMonth(entry.value, now)) monthCancelled++;
        }
      }

      final stats = DriverDashboardRideStats(
        todayCompleted: todayCompleted,
        todayCancelled: todayCancelled,
        monthCompleted: monthCompleted,
        monthCancelled: monthCancelled,
        monthEarningsIqd: monthEarnings,
        dayKey: dayKeyFor(now),
        monthKey: monthKeyFor(now),
      );
      _latestStats[driverId] = stats;
      if (controller.hasListener) controller.add(stats);
    }

    controller = StreamController<DriverDashboardRideStats>.broadcast(
      onListen: () {
        final latest = _latestStats[driverId];
        if (latest != null) controller.add(latest);
      },
    );
    _dashboardEmitHooks[driverId] = emit;

    void bindRides({required bool ordered}) {
      ridesSub?.cancel();
      Query<Map<String, dynamic>> query = _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId);
      if (ordered) {
        query = query.orderBy('createdAt', descending: true);
      }
      ridesSub = query.limit(400).snapshots().listen(
        (snapshot) {
          ridesSnap = snapshot;
          emit();
        },
        onError: (Object error) {
          debugPrint('driver ride stats error (ordered=$ordered): $error');
          if (ordered) {
            bindRides(ordered: false);
          }
        },
      );
    }

    bindRides(ordered: true);

    rejectionSub = _firestore
        .collection('drivers')
        .doc(driverId)
        .collection('rideRejections')
        .limit(500)
        .snapshots()
        .listen(
      (snapshot) {
        rejectionSnap = snapshot;
        emit();
      },
      onError: (Object error) {
        debugPrint('driver rejection stats error: $error');
      },
    );

    rootRejectionSub = _firestore
        .collection('driverRideRejections')
        .where('driverId', isEqualTo: driverId)
        .limit(500)
        .snapshots()
        .listen(
      (snapshot) {
        rootRejectionSnap = snapshot;
        emit();
      },
      onError: (Object error) {
        debugPrint('driver root rejection stats error: $error');
      },
    );

    controller.onCancel = () async {
      _dashboardEmitHooks.remove(driverId);
      await ridesSub?.cancel();
      await rejectionSub?.cancel();
      await rootRejectionSub?.cancel();
      _dashboardStreams.remove(driverId);
      _todayStreams.remove(driverId);
      _monthStreams.remove(driverId);
    };

    return controller.stream;
  }
}
