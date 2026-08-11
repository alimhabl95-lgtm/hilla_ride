import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hilla_ride/core/models/service_area_models.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:latlong2/latlong.dart';

class ServiceAreaService {
  ServiceAreaService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  StreamSubscription? _countriesSub;
  StreamSubscription? _provincesSub;
  StreamSubscription? _districtsSub;
  StreamSubscription? _subsSub;
  var _started = false;

  /// Call once at app start so customer/driver geo sync without updates.
  void startCatalogSync() {
    if (_started) return;
    _started = true;
    List<ServiceCountry> countries = const [];
    List<ServiceProvince> provinces = const [];
    List<ServiceDistrict> districts = const [];
    List<ServiceSubDistrict> subs = const [];

    void publish() {
      ServiceAreaCatalog.instance.replaceFromFirestore(
        countries: countries,
        provinces: provinces,
        districts: districts,
        subs: subs,
      );
    }

    _countriesSub = _firestore.collection('serviceCountries').snapshots().listen(
      (snap) {
        countries = snap.docs.map(ServiceCountry.fromDoc).toList();
        publish();
      },
    );
    _provincesSub = _firestore.collection('serviceProvinces').snapshots().listen(
      (snap) {
        provinces = snap.docs.map(ServiceProvince.fromDoc).toList();
        publish();
      },
    );
    _districtsSub = _firestore.collection('serviceDistricts').snapshots().listen(
      (snap) {
        districts = snap.docs.map(ServiceDistrict.fromDoc).toList();
        publish();
      },
    );
    _subsSub = _firestore.collection('serviceSubDistricts').snapshots().listen(
      (snap) {
        subs = snap.docs.map(ServiceSubDistrict.fromDoc).toList();
        publish();
      },
    );
  }

  void dispose() {
    _countriesSub?.cancel();
    _provincesSub?.cancel();
    _districtsSub?.cancel();
    _subsSub?.cancel();
    _started = false;
  }

  Stream<List<ServiceCountry>> watchCountries() {
    return _firestore.collection('serviceCountries').snapshots().map(
          (snap) => snap.docs.map(ServiceCountry.fromDoc).toList()
            ..sort((a, b) => a.nameEn.compareTo(b.nameEn)),
        );
  }

  Stream<List<ServiceProvince>> watchProvinces({String? countryId}) {
    Query<Map<String, dynamic>> q = _firestore.collection('serviceProvinces');
    if (countryId != null && countryId.isNotEmpty) {
      q = q.where('countryId', isEqualTo: countryId);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map(ServiceProvince.fromDoc).toList()
            ..sort((a, b) => a.nameEn.compareTo(b.nameEn)),
        );
  }

  Stream<List<ServiceDistrict>> watchDistricts({String? provinceId}) {
    Query<Map<String, dynamic>> q = _firestore.collection('serviceDistricts');
    if (provinceId != null && provinceId.isNotEmpty) {
      q = q.where('provinceId', isEqualTo: provinceId);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map(ServiceDistrict.fromDoc).toList()
            ..sort((a, b) => a.nameEn.compareTo(b.nameEn)),
        );
  }

  Stream<List<ServiceSubDistrict>> watchSubDistricts({String? districtId}) {
    Query<Map<String, dynamic>> q = _firestore.collection('serviceSubDistricts');
    if (districtId != null && districtId.isNotEmpty) {
      q = q.where('districtId', isEqualTo: districtId);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map(ServiceSubDistrict.fromDoc).toList()
            ..sort((a, b) => a.nameEn.compareTo(b.nameEn)),
        );
  }

  Future<void> seedDefaults() async {
    await _functions.httpsCallable('seedServiceAreas').call({});
  }

  Future<void> saveCountry(ServiceCountry country) async {
    await _functions.httpsCallable('saveServiceArea').call({
      'kind': 'country',
      'id': country.id,
      'data': {
        'nameEn': country.nameEn,
        'nameAr': country.nameAr,
        'code': country.code,
        'currency': country.currency,
        'status': country.status.value,
      },
    });
  }

  Future<void> saveProvince(ServiceProvince province) async {
    await _functions.httpsCallable('saveServiceArea').call({
      'kind': 'province',
      'id': province.id,
      'data': {
        'countryId': province.countryId,
        'nameEn': province.nameEn,
        'nameAr': province.nameAr,
        'customerVisible': province.customerVisible,
        'status': province.status.value,
      },
    });
  }

  Future<void> saveDistrict(ServiceDistrict district) async {
    await _functions.httpsCallable('saveServiceArea').call({
      'kind': 'district',
      'id': district.id,
      'data': {
        'provinceId': district.provinceId,
        'countryId': district.countryId,
        'nameEn': district.nameEn,
        'nameAr': district.nameAr,
        'customerVisible': district.customerVisible,
        'status': district.status.value,
      },
    });
  }

  Future<void> saveSubDistrict(ServiceSubDistrict sub) async {
    await _functions.httpsCallable('saveServiceArea').call({
      'kind': 'subDistrict',
      'id': sub.id,
      'data': {
        'districtId': sub.districtId,
        'provinceId': sub.provinceId,
        'countryId': sub.countryId,
        'nameEn': sub.nameEn,
        'nameAr': sub.nameAr,
        'latitude': sub.center.latitude,
        'longitude': sub.center.longitude,
        'searchRadiusKm': sub.searchRadiusKm,
        if (sub.boundary != null) 'boundary': boundaryToMapList(sub.boundary),
        'status': sub.status.value,
        'services': sub.services,
        'useGlobalCommission': sub.useGlobalCommission,
        'commissionPercent': sub.commissionPercent,
        'pricing': sub.pricing.toMap(),
        'operatingHours': sub.operatingHours.toMap(),
      },
    });
  }

  /// Persists only the `boundary` field for a sub-district — used by the
  /// Admin polygon editor so editing the boundary never touches pricing,
  /// radius, or other fields. Pass `null` to explicitly clear a previously
  /// drawn polygon and fall back to the synthesized center+radius circle.
  Future<void> saveSubDistrictBoundary({
    required String id,
    List<LatLng>? boundary,
  }) async {
    await _functions.httpsCallable('saveServiceArea').call({
      'kind': 'subDistrict',
      'id': id,
      'mergeOnly': true,
      'data': {
        'boundary': boundary != null ? boundaryToMapList(boundary) : null,
      },
    });
  }

  Future<void> setAreaStatus({
    required String kind,
    required String id,
    required ServiceAreaStatus status,
    bool cascade = true,
  }) async {
    await _functions.httpsCallable('setServiceAreaStatus').call({
      'kind': kind,
      'id': id,
      'status': status.value,
      'cascade': cascade,
    });
  }

  Future<void> archiveArea({
    required String kind,
    required String id,
  }) async {
    await setAreaStatus(
      kind: kind,
      id: id,
      status: ServiceAreaStatus.archived,
      cascade: true,
    );
  }

  Future<void> deleteArea({
    required String kind,
    required String id,
  }) async {
    await _functions.httpsCallable('deleteServiceArea').call({
      'kind': kind,
      'id': id,
    });
  }
}
