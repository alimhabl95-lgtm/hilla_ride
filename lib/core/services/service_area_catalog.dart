import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/service_area_models.dart';
import 'package:latlong2/latlong.dart';

/// In-memory geo catalog synced from Firestore.
///
/// After the first snapshot, seed data is never used — an empty active set
/// means no new rides (deactivated areas stay out immediately).
class ServiceAreaCatalog {
  ServiceAreaCatalog._();
  static final ServiceAreaCatalog instance = ServiceAreaCatalog._();

  List<ServiceDistrictNode>? _liveDistricts;
  /// All districts (active + inactive) for admin filters / labels.
  List<ServiceDistrictNode>? _allDistricts;
  Map<String, ServiceSubDistrict> _subById = {};
  Map<String, ServiceProvince> _provincesById = {};
  Map<String, ServiceCountry> _countriesById = {};
  var _synced = false;

  /// True once at least one Firestore snapshot has been applied.
  bool get hasSynced => _synced;

  /// True when live active districts are available for booking.
  bool get hasLiveData =>
      _synced && _liveDistricts != null && _liveDistricts!.isNotEmpty;

  void replaceFromFirestore({
    required List<ServiceCountry> countries,
    required List<ServiceProvince> provinces,
    required List<ServiceDistrict> districts,
    required List<ServiceSubDistrict> subs,
  }) {
    _synced = true;
    _countriesById = {for (final c in countries) c.id: c};
    _provincesById = {for (final p in provinces) p.id: p};

    bool parentActive(ServiceDistrict d) {
      final province = _provincesById[d.provinceId];
      if (province != null && !province.status.acceptsNewRides) return false;
      final countryId =
          (province != null && province.countryId.isNotEmpty)
              ? province.countryId
              : d.countryId;
      final country = _countriesById[countryId];
      if (country != null && !country.status.acceptsNewRides) return false;
      return true;
    }

    final activeDistricts = districts
        .where((d) => d.status.acceptsNewRides && parentActive(d))
        .toList();
    final activeSubs = subs
        .where(
          (s) =>
              s.status.acceptsNewRides &&
              s.supportsRide &&
              activeDistricts.any((d) => d.id == s.districtId),
        )
        .toList();
    _subById = {for (final s in activeSubs) s.id: s};

    _liveDistricts = [
      for (final d in activeDistricts)
        ServiceDistrictNode(
          id: d.id,
          nameAr: d.nameAr,
          nameEn: d.nameEn,
          customerVisible: d.customerVisible,
          subDistricts: [
            for (final s in activeSubs.where((x) => x.districtId == d.id))
              ServiceSubDistrictNode(
                id: s.id,
                nameAr: s.nameAr,
                nameEn: s.nameEn,
                center: s.center,
                searchRadiusKm: s.searchRadiusKm,
              ),
          ],
        ),
    ].where((d) => d.subDistricts.isNotEmpty).toList();

    _allDistricts = [
      for (final d in districts)
        ServiceDistrictNode(
          id: d.id,
          nameAr: d.nameAr,
          nameEn: d.nameEn,
          customerVisible: d.customerVisible,
          subDistricts: [
            for (final s in subs.where((x) => x.districtId == d.id))
              ServiceSubDistrictNode(
                id: s.id,
                nameAr: s.nameAr,
                nameEn: s.nameEn,
                center: s.center,
                searchRadiusKm: s.searchRadiusKm,
              ),
          ],
        ),
    ];
  }

  List<BabilDistrict> _nodesToBabil(List<ServiceDistrictNode> nodes) {
    return [
      for (final d in nodes)
        BabilDistrict(
          id: d.id,
          nameAr: d.nameAr,
          nameEn: d.nameEn,
          subDistricts: [
            for (final s in d.subDistricts)
              BabilSubDistrict(
                id: s.id,
                nameAr: s.nameAr,
                nameEn: s.nameEn,
                center: s.center,
                searchRadiusKm: s.searchRadiusKm,
              ),
          ],
        ),
    ];
  }

  List<BabilDistrict> get districtsAsBabil {
    if (!_synced) {
      return BabilRegions.seedDistricts;
    }
    return _nodesToBabil(_liveDistricts ?? const <ServiceDistrictNode>[]);
  }

  /// Admin city filters: prefer all configured districts; never return empty.
  List<BabilDistrict> get districtsForAdminFilters {
    if (!_synced) {
      return BabilRegions.seedDistricts;
    }
    final all = _nodesToBabil(_allDistricts ?? const <ServiceDistrictNode>[]);
    if (all.isNotEmpty) return all;
    final live = districtsAsBabil;
    if (live.isNotEmpty) return live;
    return BabilRegions.seedDistricts;
  }

  List<BabilDistrict> get customerDistrictsAsBabil {
    if (!_synced) {
      return BabilRegions.seedCustomerDistricts;
    }
    final live = _liveDistricts ?? const <ServiceDistrictNode>[];
    final visible = live.where((d) => d.customerVisible).toList();
    final source = visible.isEmpty ? live : visible;
    return [
      for (final d in source)
        BabilDistrict(
          id: d.id,
          nameAr: d.nameAr,
          nameEn: d.nameEn,
          subDistricts: [
            for (final s in d.subDistricts)
              BabilSubDistrict(
                id: s.id,
                nameAr: s.nameAr,
                nameEn: s.nameEn,
                center: s.center,
                searchRadiusKm: s.searchRadiusKm,
              ),
          ],
        ),
    ];
  }

  ServiceSubDistrict? subDistrictConfig(String id) => _subById[id];

  /// True if [point] falls inside any active sub-district radius.
  bool isWithinAnyActiveArea(LatLng point) {
    const distance = Distance();
    for (final sub in _subById.values) {
      final km = distance.as(LengthUnit.Kilometer, sub.center, point);
      if (km <= sub.searchRadiusKm) return true;
    }
    // Before first sync, fall back to seed geometry so cold-start still works.
    if (!_synced) {
      for (final d in BabilRegions.seedDistricts) {
        for (final s in d.subDistricts) {
          final km = distance.as(LengthUnit.Kilometer, s.center, point);
          if (km <= s.searchRadiusKm) return true;
        }
      }
    }
    return false;
  }

  /// Validates a district/sub pair for a new ride request.
  /// Returns null when allowed, otherwise a short error code.
  String? validateForNewRide({
    required String districtId,
    required String subDistrictId,
    LatLng? pickup,
  }) {
    if (_synced) {
      final sub = _subById[subDistrictId];
      if (sub == null || sub.districtId != districtId) {
        return 'area_inactive';
      }
      if (!sub.acceptsNewRideRequests()) {
        return sub.operatingHours.alwaysOpen ||
                sub.operatingHours.isOpenAt(DateTime.now())
            ? 'area_inactive'
            : 'area_closed';
      }
      if (pickup != null) {
        const distance = Distance();
        final km = distance.as(LengthUnit.Kilometer, sub.center, pickup);
        if (km > sub.searchRadiusKm) {
          return 'outside_area';
        }
      }
      return null;
    }
    // Pre-sync: allow seed areas only.
    final seedOk = BabilRegions.seedDistricts.any(
      (d) =>
          d.id == districtId && d.subDistricts.any((s) => s.id == subDistrictId),
    );
    return seedOk ? null : 'area_inactive';
  }
}
