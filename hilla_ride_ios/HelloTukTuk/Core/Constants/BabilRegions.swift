import CoreLocation
import Foundation

struct BabilSubDistrict: Identifiable, Hashable {
    let id: String
    let nameEn: String
    let nameAr: String
    let center: CLLocationCoordinate2D
    let searchRadiusKm: Double
    /// Optional Admin-drawn geofence polygon (open ring). When nil, an
    /// effective boundary is synthesized from `center` + `searchRadiusKm`.
    var boundary: [CLLocationCoordinate2D]? = nil

    func displayName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    static func == (lhs: BabilSubDistrict, rhs: BabilSubDistrict) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Radius (km) used to bias broad "search first" provider queries —
    /// sized from the effective boundary's bounding radius (real polygon
    /// or synthesized circle) plus a small buffer, so odd-shaped/elongated
    /// areas don't get under-biased and lose valid candidates. Always a
    /// soft bias, never a hard restriction.
    var searchBiasRadiusKm: Double {
        let effective = GeoPolygon.effectiveBoundary(
            center: center,
            radiusKm: searchRadiusKm,
            storedBoundary: boundary
        )
        let boundingKm = GeoPolygon.boundingRadiusKm(center: center, polygon: effective)
        return max(boundingKm, searchRadiusKm) + 2.0
    }
}

struct BabilDistrict: Identifiable, Hashable {
    let id: String
    let nameEn: String
    let nameAr: String
    let subDistricts: [BabilSubDistrict]

    func displayName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    static func == (lhs: BabilDistrict, rhs: BabilDistrict) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum BabilRegions {
    static let preferredCustomerDistrictId = "hashimiya"
    static let defaultSubDistrictRadiusKm = 22.0
    static let seedProvinceId = "babil"
    static let provinceNameEn = "Babil Province"
    static let provinceNameAr = "محافظة بابل"

    /// Prefer live catalog; seed only before first Firestore sync.
    @MainActor
    static var districts: [BabilDistrict] {
        ServiceAreaCatalog.shared.districtsForApps
    }

    @MainActor
    static var customerDistricts: [BabilDistrict] {
        ServiceAreaCatalog.shared.customerDistricts
    }

    @MainActor
    static var customerDistrictId: String {
        customerDistrict.id
    }

    @MainActor
    static var customerDistrict: BabilDistrict {
        let list = customerDistricts
        if list.isEmpty { return seedCustomerDistricts[0] }
        return list.first { $0.id == preferredCustomerDistrictId } ?? list[0]
    }

    /// Governorates offered to customers in the cascading area selector —
    /// dynamic, backed by Firestore, never hardcoded beyond the seed
    /// fallback used before the first sync.
    @MainActor
    static var customerProvinces: [ServiceProvinceSummary] {
        ServiceAreaCatalog.shared.customerProvinces
    }

    /// Customer-visible districts under `provinceId`.
    @MainActor
    static func customerDistricts(forProvince provinceId: String) -> [BabilDistrict] {
        ServiceAreaCatalog.shared.districtsForProvince(provinceId)
    }

    /// Governorate id that owns `districtId`.
    @MainActor
    static func provinceId(forDistrict districtId: String) -> String {
        ServiceAreaCatalog.shared.provinceIdForDistrict(districtId)
    }

    static let seedDistricts: [BabilDistrict] = [
        BabilDistrict(
            id: preferredCustomerDistrictId,
            nameEn: "Al-Hashimiya District",
            nameAr: "قضاء الهاشمية",
            subDistricts: [
                BabilSubDistrict(
                    id: "hashimiya_center",
                    nameEn: "Hashimiya Center",
                    nameAr: "ناحية مركز الهاشمية",
                    center: CLLocationCoordinate2D(latitude: 32.374, longitude: 44.665),
                    searchRadiusKm: defaultSubDistrictRadiusKm
                ),
                BabilSubDistrict(
                    id: "qasim",
                    nameEn: "Al-Qasim",
                    nameAr: "ناحية القاسم",
                    center: CLLocationCoordinate2D(latitude: 32.3014, longitude: 44.6892),
                    searchRadiusKm: 25
                ),
                BabilSubDistrict(
                    id: "madhatiyah",
                    nameEn: "Al-Madhatiyah",
                    nameAr: "ناحية المدحتية",
                    center: CLLocationCoordinate2D(latitude: 32.3964, longitude: 44.6536),
                    searchRadiusKm: 25
                ),
                BabilSubDistrict(
                    id: "shumali",
                    nameEn: "Al-Shumali",
                    nameAr: "ناحية الشوملي",
                    center: CLLocationCoordinate2D(latitude: 32.328, longitude: 44.918),
                    searchRadiusKm: 28
                ),
                BabilSubDistrict(
                    id: "taleaa",
                    nameEn: "Al-Taleaa",
                    nameAr: "ناحية الطليعة",
                    center: CLLocationCoordinate2D(latitude: 32.35, longitude: 44.78),
                    searchRadiusKm: 25
                )
            ]
        )
    ]

    static var seedCustomerDistricts: [BabilDistrict] { seedDistricts }

    @MainActor
    static func subDistrict(byId id: String) -> BabilSubDistrict {
        for district in districts {
            if let match = district.subDistricts.first(where: { $0.id == id }) {
                return match
            }
        }
        return customerDistrict.subDistricts.first ?? seedDistricts[0].subDistricts[0]
    }

    /// True when `point` falls inside the sub-district's effective boundary:
    /// its Admin-drawn polygon when present, otherwise a polygon synthesized
    /// from its center + search radius. Always a true geographic boundary
    /// check (point-in-polygon), never a plain circle-distance check.
    ///
    /// When the sub-district only has a temporary circle (no Admin-drawn
    /// polygon yet), overlapping neighboring circles are resolved by
    /// nearest center, so a point inside e.g. Qasim's circle never also
    /// counts as "inside" Al-Shumali just because both circles are large
    /// and close together in the same district.
    @MainActor
    static func isWithin(subDistrictId: String, point: CLLocationCoordinate2D) -> Bool {
        guard !subDistrictId.isEmpty else { return false }
        let sub = subDistrict(byId: subDistrictId)
        let others: [GeoArea] = districts.flatMap { district in
            district.subDistricts.compactMap { other -> GeoArea? in
                guard other.id != subDistrictId else { return nil }
                return GeoArea(center: other.center, radiusKm: other.searchRadiusKm, boundary: other.boundary)
            }
        }
        return GeoPolygon.isWithinBoundaryUnique(
            point: point,
            center: sub.center,
            radiusKm: sub.searchRadiusKm,
            storedBoundary: sub.boundary,
            others: others
        )
    }

    /// True when `point` falls inside any sub-district of `districtId`.
    /// Uses plain boundary checks (not nearest-neighbor unique) so search
    /// results near overlapping sub-district edges are not dropped.
    @MainActor
    static func isWithinDistrict(districtId: String, point: CLLocationCoordinate2D) -> Bool {
        guard let district = districts.first(where: { $0.id == districtId }) else {
            return false
        }
        return district.subDistricts.contains { sub in
            GeoPolygon.isWithinBoundary(
                point: point,
                center: sub.center,
                radiusKm: max(sub.searchRadiusKm, 8),
                storedBoundary: sub.boundary
            )
        }
    }

    /// Soft sub-district match for booking / search — Admin polygons are often
    /// tight or overlapping, so a small buffer around the area is allowed.
    @MainActor
    static func isNearSubDistrictForSearch(
        districtId: String,
        subDistrictId: String,
        point: CLLocationCoordinate2D,
        extraBufferKm: Double = 8
    ) -> Bool {
        guard !subDistrictId.isEmpty else { return false }
        if isWithin(subDistrictId: subDistrictId, point: point) {
            return true
        }
        let sub = subDistrict(byId: subDistrictId)
        // Plain boundary (no unique/nearest) — booking shouldn't fail because
        // a neighbor circle claimed the point.
        if GeoPolygon.isWithinBoundary(
            point: point,
            center: sub.center,
            radiusKm: max(sub.searchRadiusKm, 12) + extraBufferKm,
            storedBoundary: sub.boundary
        ) {
            return true
        }
        let allowed = max(sub.searchRadiusKm, sub.searchBiasRadiusKm, 12) + extraBufferKm
        return GeoMath.distanceKm(from: sub.center, to: point) <= allowed
    }

    /// Soft district match for place search — keeps Google/OSM hits that are
    /// near any sub-district center even when Admin polygons/radii are tight.
    @MainActor
    static func isNearDistrictForSearch(
        districtId: String,
        point: CLLocationCoordinate2D,
        extraBufferKm: Double = 12
    ) -> Bool {
        if isWithinDistrict(districtId: districtId, point: point) {
            return true
        }
        guard let district = districts.first(where: { $0.id == districtId }),
              !district.subDistricts.isEmpty else {
            return false
        }
        return district.subDistricts.contains { sub in
            let allowed = max(sub.searchRadiusKm, sub.searchBiasRadiusKm, 20) + extraBufferKm
            return GeoMath.distanceKm(from: sub.center, to: point) <= allowed
        }
    }

    /// Bias radius (km) large enough to cover the whole district for providers.
    @MainActor
    static func searchBiasRadiusKm(forDistrict districtId: String) -> Double {
        guard let district = districts.first(where: { $0.id == districtId }),
              !district.subDistricts.isEmpty else {
            return defaultSubDistrictRadiusKm + 10
        }
        let centers = district.subDistricts.map(\.center)
        let avgLat = centers.map(\.latitude).reduce(0, +) / Double(centers.count)
        let avgLon = centers.map(\.longitude).reduce(0, +) / Double(centers.count)
        let centroid = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
        var maxKm = defaultSubDistrictRadiusKm
        for sub in district.subDistricts {
            let reach = GeoMath.distanceKm(from: centroid, to: sub.center)
                + max(sub.searchRadiusKm, sub.searchBiasRadiusKm)
            maxKm = max(maxKm, reach)
        }
        return min(maxKm + 8, 55)
    }

    @MainActor
    static func resolveFromPoint(_ point: CLLocationCoordinate2D) -> (districtId: String, subDistrictId: String) {
        for district in districts {
            for sub in district.subDistricts {
                if GeoPolygon.isWithinBoundary(
                    point: point,
                    center: sub.center,
                    radiusKm: sub.searchRadiusKm,
                    storedBoundary: sub.boundary
                ) {
                    return (district.id, sub.id)
                }
            }
        }
        var nearestDistrict = customerDistrict.id
        var nearestSub = customerDistrict.subDistricts.first?.id ?? "hashimiya_center"
        var nearestKm = Double.greatestFiniteMagnitude
        for district in districts {
            for sub in district.subDistricts {
                let km = GeoMath.distanceKm(from: sub.center, to: point)
                if km < nearestKm {
                    nearestKm = km
                    nearestDistrict = district.id
                    nearestSub = sub.id
                }
            }
        }
        return (nearestDistrict, nearestSub)
    }
}
