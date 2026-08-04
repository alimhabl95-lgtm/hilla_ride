import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum ServiceAreaStatus {
  active,
  inactive,
  maintenance,
  archived,
}

extension ServiceAreaStatusX on ServiceAreaStatus {
  String get value => name;

  /// Areas that may accept new ride requests.
  bool get acceptsNewRides => this == ServiceAreaStatus.active;

  /// Soft-removed from ops but kept for history.
  bool get isRetired =>
      this == ServiceAreaStatus.inactive ||
      this == ServiceAreaStatus.archived ||
      this == ServiceAreaStatus.maintenance;

  static ServiceAreaStatus fromString(String? raw) {
    return ServiceAreaStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ServiceAreaStatus.inactive,
    );
  }
}

class ServiceTypeIds {
  static const ride = 'ride';
  static const food = 'food';
  static const grocery = 'grocery';
  static const pharmacy = 'pharmacy';
  static const courier = 'courier';
  static const all = [ride, food, grocery, pharmacy, courier];
}

class DayHours {
  const DayHours({this.open = '00:00', this.close = '23:59', this.closed = false});

  final String open;
  final String close;
  final bool closed;

  Map<String, dynamic> toMap() => {
        'open': open,
        'close': close,
        'closed': closed,
      };

  factory DayHours.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const DayHours();
    return DayHours(
      open: data['open'] as String? ?? '00:00',
      close: data['close'] as String? ?? '23:59',
      closed: data['closed'] as bool? ?? false,
    );
  }
}

class OperatingHours {
  const OperatingHours({
    this.alwaysOpen = true,
    this.monday = const DayHours(),
    this.tuesday = const DayHours(),
    this.wednesday = const DayHours(),
    this.thursday = const DayHours(),
    this.friday = const DayHours(),
    this.saturday = const DayHours(),
    this.sunday = const DayHours(),
  });

  final bool alwaysOpen;
  final DayHours monday;
  final DayHours tuesday;
  final DayHours wednesday;
  final DayHours thursday;
  final DayHours friday;
  final DayHours saturday;
  final DayHours sunday;

  Map<String, dynamic> toMap() => {
        'alwaysOpen': alwaysOpen,
        'monday': monday.toMap(),
        'tuesday': tuesday.toMap(),
        'wednesday': wednesday.toMap(),
        'thursday': thursday.toMap(),
        'friday': friday.toMap(),
        'saturday': saturday.toMap(),
        'sunday': sunday.toMap(),
      };

  factory OperatingHours.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const OperatingHours();
    return OperatingHours(
      alwaysOpen: data['alwaysOpen'] as bool? ?? true,
      monday: DayHours.fromMap(data['monday'] as Map<String, dynamic>?),
      tuesday: DayHours.fromMap(data['tuesday'] as Map<String, dynamic>?),
      wednesday: DayHours.fromMap(data['wednesday'] as Map<String, dynamic>?),
      thursday: DayHours.fromMap(data['thursday'] as Map<String, dynamic>?),
      friday: DayHours.fromMap(data['friday'] as Map<String, dynamic>?),
      saturday: DayHours.fromMap(data['saturday'] as Map<String, dynamic>?),
      sunday: DayHours.fromMap(data['sunday'] as Map<String, dynamic>?),
    );
  }

  DayHours hoursForWeekday(int weekday) {
    // DateTime: Monday=1 … Sunday=7
    return switch (weekday) {
      1 => monday,
      2 => tuesday,
      3 => wednesday,
      4 => thursday,
      5 => friday,
      6 => saturday,
      _ => sunday,
    };
  }

  /// Local-time check for whether the area accepts new requests now.
  bool isOpenAt(DateTime localNow) {
    if (alwaysOpen) return true;
    final day = hoursForWeekday(localNow.weekday);
    if (day.closed) return false;
    final minutes = localNow.hour * 60 + localNow.minute;
    final open = _parseHm(day.open);
    final close = _parseHm(day.close);
    if (open == null || close == null) return true;
    if (close < open) {
      // Overnight window e.g. 22:00–06:00
      return minutes >= open || minutes <= close;
    }
    return minutes >= open && minutes <= close;
  }

  static int? _parseHm(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return null;
    return h.clamp(0, 23) * 60 + m.clamp(0, 59);
  }
}

class AreaPricingRules {
  const AreaPricingRules({
    this.useGlobalPricing = true,
    this.baseFareIqd,
    this.perKmIqd,
    this.perMinuteIqd,
    this.minimumFareIqd,
    this.cancellationFeeIqd,
  });

  final bool useGlobalPricing;
  final int? baseFareIqd;
  final int? perKmIqd;
  final int? perMinuteIqd;
  final int? minimumFareIqd;
  final int? cancellationFeeIqd;

  Map<String, dynamic> toMap() => {
        'useGlobalPricing': useGlobalPricing,
        if (baseFareIqd != null) 'baseFareIqd': baseFareIqd,
        if (perKmIqd != null) 'perKmIqd': perKmIqd,
        if (perMinuteIqd != null) 'perMinuteIqd': perMinuteIqd,
        if (minimumFareIqd != null) 'minimumFareIqd': minimumFareIqd,
        if (cancellationFeeIqd != null) 'cancellationFeeIqd': cancellationFeeIqd,
      };

  factory AreaPricingRules.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AreaPricingRules();
    return AreaPricingRules(
      useGlobalPricing: data['useGlobalPricing'] as bool? ?? true,
      baseFareIqd: (data['baseFareIqd'] as num?)?.toInt(),
      perKmIqd: (data['perKmIqd'] as num?)?.toInt(),
      perMinuteIqd: (data['perMinuteIqd'] as num?)?.toInt(),
      minimumFareIqd: (data['minimumFareIqd'] as num?)?.toInt(),
      cancellationFeeIqd: (data['cancellationFeeIqd'] as num?)?.toInt(),
    );
  }
}

class ServiceCountry {
  const ServiceCountry({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.code = 'IQ',
    this.currency = 'IQD',
    this.status = ServiceAreaStatus.active,
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final String code;
  final String currency;
  final ServiceAreaStatus status;

  bool get isActive => status == ServiceAreaStatus.active;

  Map<String, dynamic> toMap() => {
        'nameEn': nameEn,
        'nameAr': nameAr,
        'code': code,
        'currency': currency,
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ServiceCountry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceCountry(
      id: doc.id,
      nameEn: data['nameEn'] as String? ?? doc.id,
      nameAr: data['nameAr'] as String? ?? doc.id,
      code: data['code'] as String? ?? 'IQ',
      currency: data['currency'] as String? ?? 'IQD',
      status: ServiceAreaStatusX.fromString(data['status'] as String?),
    );
  }
}

class ServiceProvince {
  const ServiceProvince({
    required this.id,
    required this.countryId,
    required this.nameEn,
    required this.nameAr,
    this.status = ServiceAreaStatus.active,
  });

  final String id;
  final String countryId;
  final String nameEn;
  final String nameAr;
  final ServiceAreaStatus status;

  bool get isActive => status == ServiceAreaStatus.active;

  Map<String, dynamic> toMap() => {
        'countryId': countryId,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ServiceProvince.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceProvince(
      id: doc.id,
      countryId: data['countryId'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? doc.id,
      nameAr: data['nameAr'] as String? ?? doc.id,
      status: ServiceAreaStatusX.fromString(data['status'] as String?),
    );
  }
}

class ServiceDistrict {
  const ServiceDistrict({
    required this.id,
    required this.provinceId,
    required this.countryId,
    required this.nameEn,
    required this.nameAr,
    this.customerVisible = true,
    this.status = ServiceAreaStatus.active,
  });

  final String id;
  final String provinceId;
  final String countryId;
  final String nameEn;
  final String nameAr;
  final bool customerVisible;
  final ServiceAreaStatus status;

  bool get isActive => status == ServiceAreaStatus.active;

  Map<String, dynamic> toMap() => {
        'provinceId': provinceId,
        'countryId': countryId,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'customerVisible': customerVisible,
        'status': status.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ServiceDistrict.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceDistrict(
      id: doc.id,
      provinceId: data['provinceId'] as String? ?? '',
      countryId: data['countryId'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? doc.id,
      nameAr: data['nameAr'] as String? ?? doc.id,
      customerVisible: data['customerVisible'] as bool? ?? true,
      status: ServiceAreaStatusX.fromString(data['status'] as String?),
    );
  }
}

class ServiceSubDistrict {
  const ServiceSubDistrict({
    required this.id,
    required this.districtId,
    required this.provinceId,
    required this.countryId,
    required this.nameEn,
    required this.nameAr,
    required this.center,
    this.searchRadiusKm = 22,
    this.status = ServiceAreaStatus.active,
    this.services = const [ServiceTypeIds.ride],
    this.commissionPercent,
    this.useGlobalCommission = true,
    this.pricing = const AreaPricingRules(),
    this.operatingHours = const OperatingHours(),
  });

  final String id;
  final String districtId;
  final String provinceId;
  final String countryId;
  final String nameEn;
  final String nameAr;
  final LatLng center;
  final double searchRadiusKm;
  final ServiceAreaStatus status;
  final List<String> services;
  final double? commissionPercent;
  final bool useGlobalCommission;
  final AreaPricingRules pricing;
  final OperatingHours operatingHours;

  bool get isActive => status == ServiceAreaStatus.active;
  bool get supportsRide => services.contains(ServiceTypeIds.ride);

  /// Ready for new ride requests (status + service + hours).
  bool acceptsNewRideRequests({DateTime? at}) {
    if (!isActive || !supportsRide) return false;
    return operatingHours.isOpenAt(at ?? DateTime.now());
  }

  Map<String, dynamic> toMap() => {
        'districtId': districtId,
        'provinceId': provinceId,
        'countryId': countryId,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'latitude': center.latitude,
        'longitude': center.longitude,
        'searchRadiusKm': searchRadiusKm,
        'status': status.value,
        'services': services,
        'useGlobalCommission': useGlobalCommission,
        if (commissionPercent != null) 'commissionPercent': commissionPercent,
        'pricing': pricing.toMap(),
        'operatingHours': operatingHours.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory ServiceSubDistrict.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ServiceSubDistrict(
      id: doc.id,
      districtId: data['districtId'] as String? ?? '',
      provinceId: data['provinceId'] as String? ?? '',
      countryId: data['countryId'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? doc.id,
      nameAr: data['nameAr'] as String? ?? doc.id,
      center: LatLng(
        (data['latitude'] as num?)?.toDouble() ?? 0,
        (data['longitude'] as num?)?.toDouble() ?? 0,
      ),
      searchRadiusKm: (data['searchRadiusKm'] as num?)?.toDouble() ?? 22,
      status: ServiceAreaStatusX.fromString(data['status'] as String?),
      services: (data['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [ServiceTypeIds.ride],
      commissionPercent: (data['commissionPercent'] as num?)?.toDouble(),
      useGlobalCommission: data['useGlobalCommission'] as bool? ?? true,
      pricing: AreaPricingRules.fromMap(
        data['pricing'] as Map<String, dynamic>?,
      ),
      operatingHours: OperatingHours.fromMap(
        data['operatingHours'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// Tree used by apps (compatible with previous BabilRegions shape).
class ServiceDistrictNode {
  const ServiceDistrictNode({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.subDistricts,
    this.customerVisible = true,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final bool customerVisible;
  final List<ServiceSubDistrictNode> subDistricts;
}

class ServiceSubDistrictNode {
  const ServiceSubDistrictNode({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.center,
    this.searchRadiusKm = 22,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final LatLng center;
  final double searchRadiusKm;
}
