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

  /// Customer app is limited to Al-Hashimiya district and its sub-districts.
  static const String customerDistrictId = 'hashimiya';

  static BabilDistrict get customerDistrict =>
      districts.firstWhere((d) => d.id == customerDistrictId);

  static List<BabilDistrict> get customerDistricts => [customerDistrict];

  static const List<BabilDistrict> districts = [
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
    return districts.firstWhere((d) => d.id == id, orElse: () => districts.first);
  }

  static BabilSubDistrict subDistrictById(String districtId, String subId) {
    final district = districtById(districtId);
    return district.subDistricts.firstWhere(
      (s) => s.id == subId,
      orElse: () => district.subDistricts.first,
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
    return km <= sub.searchRadiusKm;
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

    return (
      districtId: nearestDistrictId ?? customerDistrictId,
      subDistrictId: nearestSubId ?? customerDistrict.subDistricts.first.id,
    );
  }
}
