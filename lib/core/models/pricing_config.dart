class PricingBracket {
  const PricingBracket({
    required this.minKm,
    required this.maxKm,
    required this.priceIqd,
  });

  final double minKm;
  final double maxKm;
  final int priceIqd;

  Map<String, dynamic> toMap() => {
        'minKm': minKm,
        'maxKm': maxKm,
        'priceIqd': priceIqd,
      };

  factory PricingBracket.fromMap(Map<String, dynamic> map) {
    return PricingBracket(
      minKm: (map['minKm'] as num).toDouble(),
      maxKm: (map['maxKm'] as num).toDouble(),
      priceIqd: (map['priceIqd'] as num).toInt(),
    );
  }

  PricingBracket copyWith({
    double? minKm,
    double? maxKm,
    int? priceIqd,
  }) {
    return PricingBracket(
      minKm: minKm ?? this.minKm,
      maxKm: maxKm ?? this.maxKm,
      priceIqd: priceIqd ?? this.priceIqd,
    );
  }
}

class PricingConfig {
  const PricingConfig({
    required this.maxDistanceKm,
    required this.brackets,
  });

  final double maxDistanceKm;
  final List<PricingBracket> brackets;

  static const defaultMaxDistanceKm = 5.0;

  static const defaultBrackets = [
    PricingBracket(minKm: 0, maxKm: 1.25, priceIqd: 1000),
    PricingBracket(minKm: 1.26, maxKm: 2.0, priceIqd: 2000),
    PricingBracket(minKm: 2.01, maxKm: 3.5, priceIqd: 3000),
    PricingBracket(minKm: 3.51, maxKm: 5.0, priceIqd: 5000),
  ];

  static const defaults = PricingConfig(
    maxDistanceKm: defaultMaxDistanceKm,
    brackets: defaultBrackets,
  );

  Map<String, dynamic> toMap() => {
        'maxDistanceKm': maxDistanceKm,
        'brackets': brackets.map((b) => b.toMap()).toList(),
      };

  String get fingerprint {
    final bracketKey = brackets
        .map(
          (b) =>
              '${b.minKm.toStringAsFixed(2)}|${b.maxKm.toStringAsFixed(2)}|${b.priceIqd}',
        )
        .join(';');
    return '${maxDistanceKm.toStringAsFixed(2)}#$bracketKey';
  }

  factory PricingConfig.fromMap(Map<String, dynamic> map) {
    final rawBrackets = map['brackets'] as List<dynamic>? ?? const [];
    return PricingConfig(
      maxDistanceKm: (map['maxDistanceKm'] as num?)?.toDouble() ??
          defaultMaxDistanceKm,
      brackets: rawBrackets
          .map((item) => PricingBracket.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  PricingConfig copyWith({
    double? maxDistanceKm,
    List<PricingBracket>? brackets,
  }) {
    return PricingConfig(
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      brackets: brackets ?? this.brackets,
    );
  }
}

class RideQuote {
  const RideQuote({
    required this.distanceKm,
    required this.durationMinutes,
    this.fareIqd,
    this.outOfService = false,
    this.isEstimatedDistance = false,
  });

  final double distanceKm;
  final int durationMinutes;
  final int? fareIqd;
  final bool outOfService;
  final bool isEstimatedDistance;

  bool get canBook => !outOfService && fareIqd != null;
}
