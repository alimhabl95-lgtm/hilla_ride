class CommissionConfig {
  const CommissionConfig({required this.platformPercent});

  final double platformPercent;

  static const defaultPlatformPercent = 10.0;

  static const defaults = CommissionConfig(
    platformPercent: defaultPlatformPercent,
  );

  Map<String, dynamic> toMap() => {
        'platformPercent': platformPercent,
      };

  factory CommissionConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    return CommissionConfig(
      platformPercent:
          (map['platformPercent'] as num?)?.toDouble() ?? defaultPlatformPercent,
    );
  }

  CommissionConfig copyWith({double? platformPercent}) {
    return CommissionConfig(
      platformPercent: platformPercent ?? this.platformPercent,
    );
  }
}

class FareSplit {
  const FareSplit({
    required this.fareIqd,
    required this.commissionPercent,
    required this.platformCommissionIqd,
    required this.driverEarningsIqd,
  });

  final int fareIqd;
  final double commissionPercent;
  final int platformCommissionIqd;
  final int driverEarningsIqd;
}
