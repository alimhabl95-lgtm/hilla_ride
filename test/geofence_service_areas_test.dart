// Automated coverage for the geofence service-area testing checklist:
// - Al-Shumali boundary correctly includes its own center and excludes
//   points from other Babil sub-districts (the original iOS regression).
// - Switching sub-district changes which points are considered "inside".
// - Off-area points are rejected by the same boundary check used for map
//   selection / pickup / destination validation.
// - The cascading customer area selector (province -> district ->
//   sub-district) resolves correctly from live-catalog-shaped data,
//   including a brand-new Admin-added governorate/district/subdistrict
//   (dynamic expansion, no hardcoding).
import 'package:flutter_test/flutter_test.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/service_area_models.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/core/utils/geo_polygon.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Al-Shumali boundary strictly scopes search/booking', () {
    const districtId = 'hashimiya';
    const shumaliId = 'shumali';

    test('Al-Shumali center is inside its own boundary', () {
      final shumali = BabilRegions.subDistrictById(districtId, shumaliId);
      expect(
        BabilRegions.isWithinSubDistrict(districtId, shumaliId, shumali.center),
        isTrue,
      );
    });

    test('Hilla center is NOT inside Al-Shumali boundary', () {
      // Hilla center, ~30km+ away from Al-Shumali — must never leak in.
      const hillaCenter = LatLng(32.4637, 44.4197);
      expect(
        BabilRegions.isWithinSubDistrict(districtId, shumaliId, hillaCenter),
        isFalse,
      );
    });

    test('Qasim center is NOT inside Al-Shumali boundary (same district, different sub)', () {
      final qasim = BabilRegions.subDistrictById(districtId, 'qasim');
      expect(
        BabilRegions.isWithinSubDistrict(districtId, shumaliId, qasim.center),
        isFalse,
      );
    });

    test('switching sub-district changes which points are inside', () {
      final qasim = BabilRegions.subDistrictById(districtId, 'qasim');
      // Qasim's own center must be inside Qasim...
      expect(
        BabilRegions.isWithinSubDistrict(districtId, 'qasim', qasim.center),
        isTrue,
      );
      // ...but not inside Al-Shumali.
      expect(
        BabilRegions.isWithinSubDistrict(districtId, shumaliId, qasim.center),
        isFalse,
      );
    });

    test('search bias radius is always a soft, non-empty buffer around the boundary', () {
      final biasKm = BabilRegions.searchBiasRadiusKmFor(districtId, shumaliId);
      final shumali = BabilRegions.subDistrictById(districtId, shumaliId);
      expect(biasKm, greaterThanOrEqualTo(shumali.searchRadiusKm));
    });

    test('resolveFromPoint finds the correct district/sub for a point inside Al-Shumali', () {
      final shumali = BabilRegions.subDistrictById(districtId, shumaliId);
      final resolved = BabilRegions.resolveFromPoint(shumali.center);
      expect(resolved.districtId, districtId);
      expect(resolved.subDistrictId, shumaliId);
    });
  });

  group('Map/pickup/destination boundary rejection (off-area point)', () {
    test('a point clearly outside every seed sub-district boundary is rejected', () {
      // Middle of nowhere, far from any seeded Babil sub-district.
      const farAway = LatLng(30.0, 47.5);
      for (final district in BabilRegions.seedDistricts) {
        for (final sub in district.subDistricts) {
          expect(
            BabilRegions.isWithinSubDistrict(district.id, sub.id, farAway),
            isFalse,
            reason: 'farAway must not be considered inside ${district.id}/${sub.id}',
          );
        }
      }
    });
  });

  group('GeoPolygon math used by the boundary check', () {
    test('synthesized polygon contains its own center', () {
      const center = LatLng(32.328, 44.918);
      final polygon = GeoPolygon.syntheticPolygonFromCircle(center, 10);
      expect(GeoPolygon.pointInPolygon(center, polygon), isTrue);
    });

    test('a point far outside the synthesized circle is excluded', () {
      const center = LatLng(32.328, 44.918);
      const farPoint = LatLng(33.5, 46.0);
      final polygon = GeoPolygon.syntheticPolygonFromCircle(center, 10);
      expect(GeoPolygon.pointInPolygon(farPoint, polygon), isFalse);
    });

    test('effectiveBoundary prefers a stored (Admin-drawn) polygon over the synthesized circle', () {
      const center = LatLng(32.328, 44.918);
      // A small drawn polygon well inside the default 22km synthetic circle.
      final drawn = [
        const LatLng(32.330, 44.916),
        const LatLng(32.330, 44.920),
        const LatLng(32.326, 44.920),
        const LatLng(32.326, 44.916),
      ];
      final effective = GeoPolygon.effectiveBoundary(
        center: center,
        radiusKm: 22,
        storedBoundary: drawn,
      );
      expect(effective, drawn);
    });
  });

  group('Dynamic Admin-added area appears through ServiceAreaCatalog (no hardcoding)', () {
    test('a brand-new governorate/district/subdistrict added by Admin is usable immediately', () {
      const newSub = ServiceSubDistrict(
        id: 'karbala_center_sub',
        districtId: 'karbala_center',
        provinceId: 'karbala',
        countryId: 'iq',
        nameEn: 'Karbala Center',
        nameAr: 'مركز كربلاء',
        center: LatLng(32.6160, 44.0249),
        searchRadiusKm: 15,
      );

      ServiceAreaCatalog.instance.replaceFromFirestore(
        countries: const [
          ServiceCountry(id: 'iq', nameEn: 'Iraq', nameAr: 'العراق'),
        ],
        provinces: const [
          ServiceProvince(id: 'babil', countryId: 'iq', nameEn: 'Babil', nameAr: 'بابل'),
          ServiceProvince(id: 'karbala', countryId: 'iq', nameEn: 'Karbala', nameAr: 'كربلاء'),
        ],
        districts: const [
          ServiceDistrict(
            id: 'karbala_center',
            provinceId: 'karbala',
            countryId: 'iq',
            nameEn: 'Karbala Center District',
            nameAr: 'قضاء مركز كربلاء',
          ),
        ],
        subs: [newSub],
      );

      // The new governorate shows up for customers without any app update.
      final provinces = ServiceAreaCatalog.instance.customerProvinces;
      expect(provinces.any((p) => p.id == 'karbala'), isTrue);

      // Its district/sub-district resolve correctly through the cascade.
      final districts = ServiceAreaCatalog.instance.customerDistrictsForProvince('karbala');
      expect(districts, hasLength(1));
      expect(districts.single.id, 'karbala_center');
      expect(districts.single.subDistricts.single.id, 'karbala_center_sub');

      // The new sub-district's own center is inside its boundary...
      expect(
        BabilRegions.isWithinSubDistrict(
          'karbala_center',
          'karbala_center_sub',
          newSub.center,
        ),
        isTrue,
      );
      // ...and a distant point is not.
      expect(
        BabilRegions.isWithinSubDistrict(
          'karbala_center',
          'karbala_center_sub',
          const LatLng(32.328, 44.918), // Al-Shumali, Babil
        ),
        isFalse,
      );
    });
  });
}
