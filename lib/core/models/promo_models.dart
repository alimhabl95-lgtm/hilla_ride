class PromoCodeConfig {
  const PromoCodeConfig({
    required this.code,
    required this.enabled,
    required this.autoAssignOnSignup,
    required this.discountPercent,
    required this.maxDiscountIqd,
    required this.maxRides,
    this.description = '',
  });

  final String code;
  final bool enabled;
  final bool autoAssignOnSignup;
  final int discountPercent;
  final int maxDiscountIqd;
  final int maxRides;
  final String description;

  static const free3Defaults = PromoCodeConfig(
    code: 'FREE3',
    enabled: true,
    autoAssignOnSignup: true,
    discountPercent: 50,
    maxDiscountIqd: 1000,
    maxRides: 2,
    description: '50% off first 2 rides (max 1,000 IQD each)',
  );

  factory PromoCodeConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return free3Defaults;
    return PromoCodeConfig(
      code: data['code'] as String? ?? free3Defaults.code,
      enabled: data['enabled'] as bool? ?? true,
      autoAssignOnSignup: data['autoAssignOnSignup'] as bool? ?? true,
      discountPercent: (data['discountPercent'] as num?)?.toInt() ??
          free3Defaults.discountPercent,
      maxDiscountIqd: (data['maxDiscountIqd'] as num?)?.toInt() ??
          free3Defaults.maxDiscountIqd,
      maxRides: (data['maxRides'] as num?)?.toInt() ?? free3Defaults.maxRides,
      description: data['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'enabled': enabled,
      'autoAssignOnSignup': autoAssignOnSignup,
      'discountPercent': discountPercent,
      'maxDiscountIqd': maxDiscountIqd,
      'maxRides': maxRides,
      'description': description,
    };
  }
}

class PromoApplication {
  const PromoApplication({
    required this.baseFareIqd,
    required this.discountIqd,
    required this.finalFareIqd,
    this.promoCode = '',
  });

  final int baseFareIqd;
  final int discountIqd;
  final int finalFareIqd;
  final String promoCode;

  bool get hasDiscount => discountIqd > 0 && promoCode.isNotEmpty;
}

class MonthlyPrizeConfig {
  const MonthlyPrizeConfig({
    required this.prizeAmountIqd,
    required this.monthKey,
    this.winnerDriverId = '',
    this.winnerPaid = false,
  });

  final int prizeAmountIqd;
  final String monthKey;
  final String winnerDriverId;
  final bool winnerPaid;

  static const defaultPrizeIqd = 50000;

  factory MonthlyPrizeConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return MonthlyPrizeConfig(
        prizeAmountIqd: defaultPrizeIqd,
        monthKey: MonthlyPrizeConfig.currentMonthKey(),
      );
    }
    return MonthlyPrizeConfig(
      prizeAmountIqd:
          (data['prizeAmountIqd'] as num?)?.toInt() ?? defaultPrizeIqd,
      monthKey: data['monthKey'] as String? ?? currentMonthKey(),
      winnerDriverId: data['winnerDriverId'] as String? ?? '',
      winnerPaid: data['winnerPaid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prizeAmountIqd': prizeAmountIqd,
      'monthKey': monthKey,
      'winnerDriverId': winnerDriverId,
      'winnerPaid': winnerPaid,
    };
  }

  static String currentMonthKey([DateTime? date]) {
    final value = date ?? DateTime.now();
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }
}

class MonthlyLeaderboardEntry {
  const MonthlyLeaderboardEntry({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.rideCount,
    required this.rank,
    required this.isWinner,
    required this.isPaid,
  });

  final String driverId;
  final String name;
  final String phone;
  final int rideCount;
  final int rank;
  final bool isWinner;
  final bool isPaid;
}

class DriverMonthlyStats {
  const DriverMonthlyStats({
    required this.rideCount,
    required this.rank,
    required this.totalDrivers,
    required this.prizeAmountIqd,
    required this.monthKey,
  });

  final int rideCount;
  final int rank;
  final int totalDrivers;
  final int prizeAmountIqd;
  final String monthKey;
}
