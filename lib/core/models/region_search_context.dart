import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:latlong2/latlong.dart';

/// Selected district + sub-district used to scope map search.
class RegionSearchContext {
  const RegionSearchContext({
    required this.districtId,
    this.subDistrictId,
  });

  final String districtId;
  final String? subDistrictId;

  bool get hasSubDistrict =>
      subDistrictId != null && subDistrictId!.trim().isNotEmpty;

  BabilDistrict get district => BabilRegions.districtById(districtId);

  BabilSubDistrict get subDistrict {
    if (!hasSubDistrict) {
      throw StateError('Sub-district not selected');
    }
    return BabilRegions.subDistrictById(districtId, subDistrictId!);
  }

  BabilSubDistrict? get subDistrictOrNull {
    if (!hasSubDistrict) return null;
    return BabilRegions.subDistrictById(districtId, subDistrictId!);
  }

  String label({required bool isArabic}) {
    if (!hasSubDistrict) {
      return isArabic ? district.nameAr : district.nameEn;
    }
    final sub = subDistrictOrNull!;
    return isArabic ? sub.nameAr : sub.nameEn;
  }

  double get searchRadiusKm {
    if (!hasSubDistrict) {
      return BabilRegions.defaultSubDistrictRadiusKm;
    }
    return BabilRegions.searchRadiusKmFor(districtId, subDistrictId!);
  }

  LatLng get searchCenter {
    if (!hasSubDistrict) {
      return district.subDistricts.first.center;
    }
    return subDistrict.center;
  }
}
