import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/service_area_models.dart';
import 'package:hilla_ride/core/utils/geo_polygon.dart';
import 'package:latlong2/latlong.dart';

/// In-memory geo catalog synced from Firestore.
///
/// After the first snapshot, seed data is never used — an empty active set
/// means no new rides (deactivated areas stay out immediately).
class ServiceAreaCatalog extends ChangeNotifier {
  ServiceAreaCatalog._();
  static final ServiceAreaCatalog instance = ServiceAreaCatalog._();

  static const _seedProvinceId = 'babil';
  static const _seedCountryId = 'iq';

  List<ServiceDistrictNode>? _liveDistricts;
  /// All districts (active + inactive) for admin filters / labels.
  List<ServiceDistrictNode>? _allDistricts;
  List<ServiceDistrict> _rawDistricts = const [];
  List<ServiceSubDistrict> _rawSubs = const [];
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
    _rawDistricts = List<ServiceDistrict>.from(districts);
    _rawSubs = List<ServiceSubDistrict>.from(subs);

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
                boundary: s.boundary,
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
                boundary: s.boundary,
              ),
          ],
        ),
    ];
    notifyListeners();
  }

  List<ServiceProvince> get _seedProvinces => [
        ServiceProvince(
          id: _seedProvinceId,
          countryId: _seedCountryId,
          nameEn: BabilRegions.provinceNameEn,
          nameAr: BabilRegions.provinceNameAr,
        ),
      ];

  List<ServiceDistrict> get _seedDistrictsAsService => [
        for (final d in BabilRegions.seedDistricts)
          ServiceDistrict(
            id: d.id,
            provinceId: _seedProvinceId,
            countryId: _seedCountryId,
            nameEn: d.nameEn,
            nameAr: d.nameAr,
          ),
      ];

  List<ServiceSubDistrict> get _seedSubsAsService => [
        for (final d in BabilRegions.seedDistricts)
          for (final s in d.subDistricts)
            ServiceSubDistrict(
              id: s.id,
              districtId: d.id,
              provinceId: _seedProvinceId,
              countryId: _seedCountryId,
              nameEn: s.nameEn,
              nameAr: s.nameAr,
              center: s.center,
              searchRadiusKm: s.searchRadiusKm,
            ),
      ];

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
                boundary: s.boundary,
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
                boundary: s.boundary,
              ),
          ],
        ),
    ];
  }

  ServiceSubDistrict? subDistrictConfig(String id) => _subById[id];

  /// All governorates (provinces) for admin filters — dynamic, never hardcoded.
  List<ServiceProvince> get provincesForAdminFilters {
    final list = _provincesById.values.toList();
    if (list.isEmpty) return _seedProvinces;
    list.sort((a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()));
    return list;
  }

  /// Governorates offered to customers in the cascading area selector:
  /// active + customerVisible, with seed fallback so cold-start (before the
  /// first Firestore snapshot) still shows Babil. Never empty. New
  /// governorates (e.g. Karbala, Najaf) appear automatically once Admin
  /// activates them — no app update required.
  List<ServiceProvince> get customerProvinces {
    if (!_synced) return _seedProvinces;
    final all = _provincesById.values.toList();
    final visible = all.where((p) => p.isActive && p.customerVisible).toList();
    final list = visible.isEmpty ? all : visible;
    if (list.isEmpty) return _seedProvinces;
    list.sort((a, b) => a.nameEn.toLowerCase().compareTo(b.nameEn.toLowerCase()));
    return list;
  }

  /// Customer-visible districts (with their customer-visible sub-districts)
  /// under [provinceId], matching the same active/customerVisible filtering
  /// as [customerDistrictsAsBabil]. Backed entirely by live Firestore data
  /// once synced, so Admin-added districts appear without an app update.
  List<BabilDistrict> customerDistrictsForProvince(String provinceId) {
    final all = customerDistrictsAsBabil;
    if (provinceId.isEmpty) return all;
    if (!_synced) {
      return provinceId == _seedProvinceId ? all : const [];
    }
    final idsInProvince = _rawDistricts
        .where((d) => d.provinceId == provinceId)
        .map((d) => d.id)
        .toSet();
    return all.where((d) => idsInProvince.contains(d.id)).toList();
  }

  List<ServiceDistrict> get _allDistrictsForAdmin {
    if (_rawDistricts.isNotEmpty) return _rawDistricts;
    return _seedDistrictsAsService;
  }

  List<ServiceSubDistrict> get _allSubsForAdmin {
    if (_rawSubs.isNotEmpty) return _rawSubs;
    return _seedSubsAsService;
  }

  List<ServiceDistrict> districtsForProvince(String? provinceId) {
    final source = _allDistrictsForAdmin;
    if (provinceId == null || provinceId.isEmpty) return source;
    return source.where((d) => d.provinceId == provinceId).toList();
  }

  List<ServiceSubDistrict> subsForDistrict(String? districtId) {
    final source = _allSubsForAdmin;
    if (districtId == null || districtId.isEmpty) return source;
    return source.where((s) => s.districtId == districtId).toList();
  }

  String? provinceIdForDistrict(String districtId) {
    for (final d in _allDistrictsForAdmin) {
      if (d.id == districtId) return d.provinceId;
    }
    return _seedProvinceId;
  }

  ServiceProvince? provinceById(String id) {
    final p = _provincesById[id];
    if (p != null) return p;
    for (final seed in _seedProvinces) {
      if (seed.id == id) return seed;
    }
    return null;
  }

  ServiceDistrict? districtById(String id) {
    for (final d in _allDistrictsForAdmin) {
      if (d.id == id) return d;
    }
    return null;
  }

  String localizedProvinceName(String id, {required bool isAr}) {
    if (id == _seedProvinceId) {
      return isAr ? BabilRegions.provinceNameAr : BabilRegions.provinceNameEn;
    }
    final p = provinceById(id);
    if (p == null) return id;
    return isAr ? p.nameAr : p.nameEn;
  }

  String localizedDistrictName(String id, {required bool isAr}) {
    final d = districtById(id);
    if (d == null) {
      final seed = BabilRegions.districtById(id);
      return isAr ? seed.nameAr : seed.nameEn;
    }
    return isAr ? d.nameAr : d.nameEn;
  }

  String localizedSubName(String id, {required bool isAr}) {
    for (final s in _allSubsForAdmin) {
      if (s.id == id) return isAr ? s.nameAr : s.nameEn;
    }
    final live = _subById[id];
    if (live != null) return isAr ? live.nameAr : live.nameEn;
    for (final d in BabilRegions.seedDistricts) {
      for (final s in d.subDistricts) {
        if (s.id == id) return isAr ? s.nameAr : s.nameEn;
      }
    }
    return id;
  }

  /// True if [point] falls inside any active sub-district's effective
  /// boundary (Admin-drawn polygon, or one synthesized from center + radius).
  bool isWithinAnyActiveArea(LatLng point) {
    for (final sub in _subById.values) {
      if (GeoPolygon.isWithinBoundary(
        point: point,
        center: sub.center,
        radiusKm: sub.searchRadiusKm,
        storedBoundary: sub.boundary,
      )) {
        return true;
      }
    }
    // Before first sync, fall back to seed geometry so cold-start still works.
    if (!_synced) {
      for (final d in BabilRegions.seedDistricts) {
        for (final s in d.subDistricts) {
          if (GeoPolygon.isWithinBoundary(
            point: point,
            center: s.center,
            radiusKm: s.searchRadiusKm,
            storedBoundary: s.boundary,
          )) {
            return true;
          }
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
    LatLng? destination,
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
      bool withinSub(LatLng point) {
        return GeoPolygon.isWithinBoundaryUnique(
          point: point,
          center: sub.center,
          radiusKm: sub.searchRadiusKm,
          storedBoundary: sub.boundary,
          others: [
            for (final other in _subById.values)
              if (other.id != sub.id)
                GeoArea(
                  center: other.center,
                  radiusKm: other.searchRadiusKm,
                  boundary: other.boundary,
                ),
          ],
        );
      }

      if (pickup != null && !withinSub(pickup)) {
        return 'outside_area';
      }
      if (destination != null && !withinSub(destination)) {
        return 'outside_area';
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
