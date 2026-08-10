import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:latlong2/latlong.dart';

class BabilSubDistrict {
  const BabilSubDistrict({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.center,
    this.searchRadiusKm = BabilRegions.defaultSubDistrictRadiusKm,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final LatLng center;
  final double searchRadiusKm;
}

class BabilDistrict {
  const BabilDistrict({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.subDistricts,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final List<BabilSubDistrict> subDistricts;
}

/// Service area locked to Babil province (Iraq).
class BabilRegions {
  BabilRegions._();

  static const String provinceNameAr = 'محافظة بابل';
  static const String provinceNameEn = 'Babil Province';
  static const double defaultSubDistrictRadiusKm = 22.0;
  static const Distance _distance = Distance();

  /// Preferred customer district id when present in the live catalog.
  static const String preferredCustomerDistrictId = 'hashimiya';

  /// Backward-compatible alias — prefer [customerDistrict].id at call sites.
  static String get customerDistrictId => customerDistrict.id;

  static BabilDistrict get customerDistrict {
    final list = customerDistricts;
    if (list.isEmpty) {
      return seedCustomerDistricts.first;
    }
    return list.firstWhere(
      (d) => d.id == preferredCustomerDistrictId,
      orElse: () => list.first,
    );
  }

  /// Live Firestore catalog when available; otherwise hardcoded seed.
  static List<BabilDistrict> get districts =>
      ServiceAreaCatalog.instance.districtsAsBabil;

  /// Admin dropdowns: all configured cities, with seed fallback (never empty).
  static List<BabilDistrict> get districtsForFilters =>
      ServiceAreaCatalog.instance.districtsForAdminFilters;

  static List<BabilDistrict> get customerDistricts =>
      ServiceAreaCatalog.instance.customerDistrictsAsBabil;

  static List<BabilDistrict> get seedCustomerDistricts {
    final hashimiya = seedDistricts.firstWhere(
      (d) => d.id == preferredCustomerDistrictId,
      orElse: () => seedDistricts.first,
    );
    return [hashimiya];
  }

  /// Built-in seed used until managers publish service areas in Admin.
  static const List<BabilDistrict> seedDistricts = [
    BabilDistrict(
      id: 'hilla',
      nameAr: 'قضاء الحلة',
      nameEn: 'Al-Hillah District',
      subDistricts: [
        BabilSubDistrict(
          id: 'hilla_center',
          nameAr: 'ناحية مركز الحلة',
          nameEn: 'Hilla Center',
          center: LatLng(32.4637, 44.4197),
        ),
        BabilSubDistrict(
          id: 'jameaa',
          nameAr: 'ناحية الجامعة',
          nameEn: 'Al-Jamiyah',
          center: LatLng(32.461, 44.415),
        ),
        BabilSubDistrict(
          id: 'qadisiyah',
          nameAr: 'حي القادسية',
          nameEn: 'Al-Qadisiyah',
          center: LatLng(32.471, 44.425),
        ),
      ],
    ),
    BabilDistrict(
      id: 'mahawil',
      nameAr: 'قضاء المحاويل',
      nameEn: 'Al-Mahawil District',
      subDistricts: [
        BabilSubDistrict(
          id: 'mahawil_center',
          nameAr: 'ناحية مركز المحاويل',
          nameEn: 'Mahawil Center',
          center: LatLng(32.655, 44.385),
        ),
      ],
    ),
    BabilDistrict(
      id: 'musayab',
      nameAr: 'قضاء المسيب',
      nameEn: 'Al-Musayab District',
      subDistricts: [
        BabilSubDistrict(
          id: 'musayab_center',
          nameAr: 'ناحية مركز المسيب',
          nameEn: 'Musayab Center',
          center: LatLng(32.778, 44.290),
        ),
      ],
    ),
    BabilDistrict(
      id: 'hashimiya',
      nameAr: 'قضاء الهاشمية',
      nameEn: 'Al-Hashimiya District',
      subDistricts: [
        BabilSubDistrict(
          id: 'hashimiya_center',
          nameAr: 'ناحية مركز الهاشمية',
          nameEn: 'Hashimiya Center',
          center: LatLng(32.374, 44.665),
        ),
        BabilSubDistrict(
          id: 'qasim',
          nameAr: 'ناحية القاسم',
          nameEn: 'Al-Qasim',
          center: LatLng(32.3014, 44.6892),
          searchRadiusKm: 25,
        ),
        BabilSubDistrict(
          id: 'madhatiyah',
          nameAr: 'ناحية المدحتية',
          nameEn: 'Al-Madhatiyah',
          center: LatLng(32.3964, 44.6536),
          searchRadiusKm: 25,
        ),
        BabilSubDistrict(
          id: 'shumali',
          nameAr: 'ناحية الشوملي',
          nameEn: 'Al-Shumali',
          center: LatLng(32.328, 44.918),
          searchRadiusKm: 28,
        ),
        BabilSubDistrict(
          id: 'taleaa',
          nameAr: 'ناحية الطليعة',
          nameEn: 'Al-Taleaa',
          center: LatLng(32.35, 44.78),
          searchRadiusKm: 25,
        ),
      ],
    ),
  ];

  static BabilDistrict districtById(String id) {
    for (final d in districts) {
      if (d.id == id) return d;
    }
    for (final d in districtsForFilters) {
      if (d.id == id) return d;
    }
    for (final d in seedDistricts) {
      if (d.id == id) return d;
    }
    return seedDistricts.first;
  }

  static BabilSubDistrict subDistrictById(String districtId, String subId) {
    final district = districtById(districtId);
    return district.subDistricts.firstWhere(
      (s) => s.id == subId,
      orElse: () => district.subDistricts.isNotEmpty
          ? district.subDistricts.first
          : const BabilSubDistrict(
              id: 'hashimiya_center',
              nameAr: 'ناحية مركز الهاشمية',
              nameEn: 'Hashimiya Center',
              center: LatLng(32.374, 44.665),
            ),
    );
  }

  static double searchRadiusKmFor(String districtId, String subDistrictId) {
    return subDistrictById(districtId, subDistrictId).searchRadiusKm;
  }

  static bool isWithinSubDistrict(
    String districtId,
    String subDistrictId,
    LatLng point,
  ) {
    final sub = subDistrictById(districtId, subDistrictId);
    final km = _distance.as(LengthUnit.Kilometer, sub.center, point);
    if (km > sub.searchRadiusKm) {
      return false;
    }
    return _assignedSubDistrict(point)?.id == subDistrictId;
  }

  /// Nearest sub-district whose radius contains [point], if any.
  static BabilSubDistrict? _assignedSubDistrict(LatLng point) {
    BabilSubDistrict? nearest;
    var nearestKm = double.infinity;

    for (final district in districts) {
      for (final candidate in district.subDistricts) {
        final km = _distance.as(LengthUnit.Kilometer, candidate.center, point);
        if (km <= candidate.searchRadiusKm && km < nearestKm) {
          nearestKm = km;
          nearest = candidate;
        }
      }
    }

    return nearest;
  }

  static bool isWithinDistrict(String districtId, LatLng point) {
    final district = districtById(districtId);
    return district.subDistricts.any(
      (sub) => isWithinSubDistrict(districtId, sub.id, point),
    );
  }

  /// Finds the Babil district/sub-district that contains [point], or the nearest
  /// sub-district center when GPS is slightly outside the radius.
  static ({String districtId, String subDistrictId}) resolveFromPoint(
    LatLng point,
  ) {
    for (final district in districts) {
      for (final sub in district.subDistricts) {
        if (isWithinSubDistrict(district.id, sub.id, point)) {
          return (districtId: district.id, subDistrictId: sub.id);
        }
      }
    }

    String? nearestDistrictId;
    String? nearestSubId;
    var nearestKm = double.infinity;

    for (final district in districts) {
      for (final sub in district.subDistricts) {
        final km = _distance.as(LengthUnit.Kilometer, sub.center, point);
        if (km < nearestKm) {
          nearestKm = km;
          nearestDistrictId = district.id;
          nearestSubId = sub.id;
        }
      }
    }

    final fallback = customerDistricts.isNotEmpty
        ? customerDistricts.first
        : seedCustomerDistricts.first;
    return (
      districtId: nearestDistrictId ?? fallback.id,
      subDistrictId: nearestSubId ??
          (fallback.subDistricts.isNotEmpty
              ? fallback.subDistricts.first.id
              : preferredCustomerDistrictId),
    );
  }
}
