import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';

class DayBucket {
  const DayBucket({
    required this.day,
    this.trips = 0,
    this.platformRevenueIqd = 0,
    this.gmvIqd = 0,
    this.newUsers = 0,
    this.activeDrivers = 0,
  });

  final DateTime day;
  final int trips;
  final int platformRevenueIqd;
  final int gmvIqd;
  final int newUsers;
  final int activeDrivers;

  DayBucket copyWith({
    int? trips,
    int? platformRevenueIqd,
    int? gmvIqd,
    int? newUsers,
    int? activeDrivers,
  }) {
    return DayBucket(
      day: day,
      trips: trips ?? this.trips,
      platformRevenueIqd: platformRevenueIqd ?? this.platformRevenueIqd,
      gmvIqd: gmvIqd ?? this.gmvIqd,
      newUsers: newUsers ?? this.newUsers,
      activeDrivers: activeDrivers ?? this.activeDrivers,
    );
  }
}

class AdminOverviewStats {
  const AdminOverviewStats({
    required this.tripsToday,
    required this.activeTrips,
    required this.completedToday,
    required this.cancelledToday,
    required this.onlineDrivers,
    required this.offlineDrivers,
    required this.totalCustomers,
    required this.totalDrivers,
    required this.dailyRevenueIqd,
    required this.weeklyRevenueIqd,
    required this.monthlyRevenueIqd,
    required this.dailyGmvIqd,
    required this.weeklyGmvIqd,
    required this.monthlyGmvIqd,
    required this.averageDriverRating,
    required this.searchingCount,
    required this.matchedCount,
    required this.inProgressCount,
    required this.dayBuckets,
    required this.recentTrips,
    required this.recentCustomers,
    required this.recentDrivers,
    required this.blockedWalletDrivers,
    required this.highDebtDrivers,
    this.walletBalanceTotalIqd = 0,
    this.rewardsIssuedIqd = 0,
    this.activeRestaurants = 0,
    this.activeSupermarkets = 0,
    this.activePharmacies = 0,
    this.activeBusinesses = 0,
    this.ordersToday = 0,
    this.deliveryRevenueIqd = 0,
  });

  final int tripsToday;
  final int activeTrips;
  final int completedToday;
  final int cancelledToday;
  final int onlineDrivers;
  final int offlineDrivers;
  final int totalCustomers;
  final int totalDrivers;
  final int dailyRevenueIqd;
  final int weeklyRevenueIqd;
  final int monthlyRevenueIqd;
  final int dailyGmvIqd;
  final int weeklyGmvIqd;
  final int monthlyGmvIqd;
  final double averageDriverRating;
  final int searchingCount;
  final int matchedCount;
  final int inProgressCount;
  final List<DayBucket> dayBuckets;
  final List<Ride> recentTrips;
  final List<AppUser> recentCustomers;
  final List<DriverProfile> recentDrivers;
  final List<DriverProfile> blockedWalletDrivers;
  final List<DriverProfile> highDebtDrivers;
  final int walletBalanceTotalIqd;
  final int rewardsIssuedIqd;
  final int activeRestaurants;
  final int activeSupermarkets;
  final int activePharmacies;
  final int activeBusinesses;
  final int ordersToday;
  final int deliveryRevenueIqd;

  static DateTime startOfLocalDay([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static AdminOverviewStats compute({
    required List<Ride> activeRides,
    required List<Ride> ridesSinceMonth,
    required List<Ride> completedSinceMonth,
    required List<Ride> cancelledSinceMonth,
    required List<DriverProfile> drivers,
    required List<AppUser> customers,
    List<BusinessPartner> businesses = const [],
    List<BusinessOrder> orders = const [],
    int chartDays = 14,
  }) {
    final now = DateTime.now();
    final todayStart = startOfLocalDay(now);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final monthStart = todayStart.subtract(const Duration(days: 29));
    final chartStart = todayStart.subtract(Duration(days: chartDays - 1));

    final tripsToday = ridesSinceMonth
        .where((r) => (r.createdAt ?? DateTime(1970)).isAfter(todayStart) ||
            (r.createdAt ?? DateTime(1970)).isAtSameMomentAs(todayStart))
        .length;

    final completedToday = completedSinceMonth.where((r) {
      final t = r.completedAt ?? r.createdAt;
      return t != null && !t.isBefore(todayStart);
    }).toList();

    final cancelledToday = cancelledSinceMonth.where((r) {
      final t = r.createdAt;
      return t != null && !t.isBefore(todayStart);
    }).length;

    int revenueIn(DateTime start, {required bool gmv}) {
      var sum = 0;
      for (final r in completedSinceMonth) {
        final t = r.completedAt ?? r.createdAt;
        if (t == null || t.isBefore(start)) continue;
        sum += gmv ? r.fareAmountIqd : r.platformCommissionIqd;
      }
      return sum;
    }

    final approvedDrivers =
        drivers.where((d) => d.isApproved && !d.isRemoved).toList();
    final online = approvedDrivers.where((d) => d.isOnline).length;
    final offline = approvedDrivers.length - online;

    double ratingSum = 0;
    var ratingWeight = 0;
    for (final d in approvedDrivers) {
      final count = d.ratingCount > 0 ? d.ratingCount : (d.rating > 0 ? 1 : 0);
      if (count <= 0) continue;
      ratingSum += d.rating * count;
      ratingWeight += count;
    }
    final avgRating = ratingWeight == 0 ? 0.0 : ratingSum / ratingWeight;

    final buckets = <DateTime, DayBucket>{};
    for (var i = 0; i < chartDays; i++) {
      final day = chartStart.add(Duration(days: i));
      buckets[day] = DayBucket(day: day);
    }

    final driversPerDay = <DateTime, Set<String>>{};

    for (final r in completedSinceMonth) {
      final t = r.completedAt ?? r.createdAt;
      if (t == null) continue;
      final key = dayKey(t);
      if (!buckets.containsKey(key)) continue;
      final b = buckets[key]!;
      buckets[key] = b.copyWith(
        trips: b.trips + 1,
        platformRevenueIqd: b.platformRevenueIqd + r.platformCommissionIqd,
        gmvIqd: b.gmvIqd + r.fareAmountIqd,
      );
      if (r.driverId != null && r.driverId!.isNotEmpty) {
        driversPerDay.putIfAbsent(key, () => <String>{}).add(r.driverId!);
      }
    }

    for (final c in customers) {
      final t = c.createdAt;
      if (t == null) continue;
      final key = dayKey(t);
      if (!buckets.containsKey(key)) continue;
      final b = buckets[key]!;
      buckets[key] = b.copyWith(newUsers: b.newUsers + 1);
    }
    for (final d in drivers) {
      final t = d.createdAt;
      if (t == null) continue;
      final key = dayKey(t);
      if (!buckets.containsKey(key)) continue;
      final b = buckets[key]!;
      buckets[key] = b.copyWith(newUsers: b.newUsers + 1);
    }

    for (final entry in driversPerDay.entries) {
      final b = buckets[entry.key];
      if (b == null) continue;
      buckets[entry.key] = b.copyWith(activeDrivers: entry.value.length);
    }

    final dayBuckets = buckets.keys.toList()..sort();
    final sortedBuckets = dayBuckets.map((d) => buckets[d]!).toList();

    final recentCustomers = [...customers]
      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    final recentDrivers = [...drivers]
      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));

    final recentTrips = [...ridesSinceMonth]
      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));

    final blocked = approvedDrivers
        .where((d) => d.walletStatus == 'blocked')
        .take(8)
        .toList();
    final highDebt = approvedDrivers
        .where((d) => d.outstandingPlatformCommissionIqd >= 10000)
        .toList()
      ..sort((a, b) => b.outstandingPlatformCommissionIqd
          .compareTo(a.outstandingPlatformCommissionIqd));

    final walletBalanceTotalIqd = approvedDrivers.fold<int>(
      0,
      (sum, d) => sum + d.walletBalanceIqd,
    );
    final rewardsIssuedIqd = approvedDrivers.fold<int>(
      0,
      (sum, d) => sum + d.totalBonusGrantedIqd,
    );

    final liveBusinesses =
        businesses.where((b) => b.isLive && !b.temporarilyClosed).toList();
    final activeRestaurants =
        liveBusinesses.where((b) => b.typeId == 'restaurant').length;
    final activeSupermarkets =
        liveBusinesses.where((b) => b.typeId == 'supermarket').length;
    final activePharmacies =
        liveBusinesses.where((b) => b.typeId == 'pharmacy').length;

    final ordersTodayList = orders.where((o) {
      final t = o.createdAt;
      return t != null && !t.isBefore(todayStart);
    }).toList();
    final ordersToday = ordersTodayList.length;
    final deliveryRevenueIqd = ordersTodayList
        .where((o) => o.status == BusinessOrderStatus.delivered)
        .fold<int>(0, (sum, o) => sum + o.platformCommissionIqd);

    return AdminOverviewStats(
      tripsToday: tripsToday,
      activeTrips: activeRides.length,
      completedToday: completedToday.length,
      cancelledToday: cancelledToday,
      onlineDrivers: online,
      offlineDrivers: offline,
      totalCustomers: customers.length,
      totalDrivers: approvedDrivers.length,
      dailyRevenueIqd: revenueIn(todayStart, gmv: false),
      weeklyRevenueIqd: revenueIn(weekStart, gmv: false),
      monthlyRevenueIqd: revenueIn(monthStart, gmv: false),
      dailyGmvIqd: revenueIn(todayStart, gmv: true),
      weeklyGmvIqd: revenueIn(weekStart, gmv: true),
      monthlyGmvIqd: revenueIn(monthStart, gmv: true),
      averageDriverRating: avgRating,
      searchingCount:
          activeRides.where((r) => r.status == RideStatus.searching).length,
      matchedCount:
          activeRides.where((r) => r.status == RideStatus.matched).length,
      inProgressCount: activeRides
          .where((r) =>
              r.status == RideStatus.inProgress ||
              r.status == RideStatus.accepted ||
              r.status == RideStatus.awaitingCashPayment)
          .length,
      dayBuckets: sortedBuckets,
      recentTrips: recentTrips.take(10).toList(),
      recentCustomers: recentCustomers.take(8).toList(),
      recentDrivers: recentDrivers.take(8).toList(),
      blockedWalletDrivers: blocked,
      highDebtDrivers: highDebt.take(8).toList(),
      walletBalanceTotalIqd: walletBalanceTotalIqd,
      rewardsIssuedIqd: rewardsIssuedIqd,
      activeRestaurants: activeRestaurants,
      activeSupermarkets: activeSupermarkets,
      activePharmacies: activePharmacies,
      activeBusinesses: liveBusinesses.length,
      ordersToday: ordersToday,
      deliveryRevenueIqd: deliveryRevenueIqd,
    );
  }
}
