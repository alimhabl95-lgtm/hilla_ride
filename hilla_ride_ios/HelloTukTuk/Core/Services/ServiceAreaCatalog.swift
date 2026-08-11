import CoreLocation
import FirebaseFirestore
import Foundation

/// Lightweight governorate summary for the customer cascading area
/// selector (Governorate → District → Subdistrict). Iraq is fixed and never
/// shown; this only lists governorates such as Babil, Karbala, Najaf, etc.
struct ServiceProvinceSummary: Identifiable, Hashable {
    let id: String
    let nameEn: String
    let nameAr: String

    func displayName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }
}

/// Live Iraq service-area catalog (Province → District → Subdistrict).
/// After the first Firestore snapshot, seed data is never used for booking.
@MainActor
final class ServiceAreaCatalog: ObservableObject {
    static let shared = ServiceAreaCatalog()

    @Published private(set) var synced = false
    @Published private(set) var liveDistricts: [BabilDistrict] = []

    private var listeners: [ListenerRegistration] = []
    private var countries: [String: [String: Any]] = [:]
    private var provinces: [String: [String: Any]] = [:]
    private var districts: [String: [String: Any]] = [:]
    private var subs: [String: [String: Any]] = [:]

    private init() {}

    func start() {
        guard listeners.isEmpty else { return }
        let db = Firestore.firestore()
        listeners.append(db.collection("serviceCountries").addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("ServiceAreaCatalog serviceCountries error: \(error.localizedDescription)")
                    return
                }
                guard let snap else { return }
                self.countries = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
        listeners.append(db.collection("serviceProvinces").addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("ServiceAreaCatalog serviceProvinces error: \(error.localizedDescription)")
                    return
                }
                guard let snap else { return }
                self.provinces = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
        listeners.append(db.collection("serviceDistricts").addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("ServiceAreaCatalog serviceDistricts error: \(error.localizedDescription)")
                    return
                }
                guard let snap else { return }
                self.districts = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
        listeners.append(db.collection("serviceSubDistricts").addSnapshotListener { [weak self] snap, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    print("ServiceAreaCatalog serviceSubDistricts error: \(error.localizedDescription)")
                    return
                }
                guard let snap else { return }
                self.subs = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
    }

    var districtsForApps: [BabilDistrict] {
        if !synced { return BabilRegions.seedDistricts }
        return liveDistricts
    }

    var customerDistricts: [BabilDistrict] {
        if !synced { return BabilRegions.seedCustomerDistricts }
        let visible = liveDistricts.filter { district in
            if let data = districts[district.id] {
                return (data["customerVisible"] as? Bool) ?? true
            }
            return true
        }
        let list = visible.isEmpty ? liveDistricts : visible
        if list.isEmpty { return BabilRegions.seedCustomerDistricts }
        return list
    }

    /// Governorates offered to customers in the cascading area selector:
    /// active + customerVisible, with a Babil seed fallback before the
    /// first Firestore sync. Never empty. New governorates (e.g. Karbala,
    /// Najaf) appear automatically once Admin activates them — no app
    /// update required.
    var customerProvinces: [ServiceProvinceSummary] {
        let seed = [
            ServiceProvinceSummary(
                id: BabilRegions.seedProvinceId,
                nameEn: BabilRegions.provinceNameEn,
                nameAr: BabilRegions.provinceNameAr
            )
        ]
        if !synced { return seed }
        let all = provinces.map { id, data in
            ServiceProvinceSummary(
                id: id,
                nameEn: data["nameEn"] as? String ?? id,
                nameAr: data["nameAr"] as? String ?? id
            )
        }
        let visible = all.filter { p in
            guard let data = provinces[p.id] else { return true }
            let customerVisible = (data["customerVisible"] as? Bool) ?? true
            return customerVisible && accepts(data["status"] as? String)
        }
        let list = visible.isEmpty ? all : visible
        let result = list.isEmpty ? seed : list
        return result.sorted { $0.nameEn < $1.nameEn }
    }

    /// Customer-visible districts (with their sub-districts) under
    /// `provinceId`, matching the same active/customerVisible filtering as
    /// `customerDistricts`. Backed entirely by live Firestore data once
    /// synced, so Admin-added districts appear without an app update.
    func districtsForProvince(_ provinceId: String) -> [BabilDistrict] {
        let all = customerDistricts
        if provinceId.isEmpty { return all }
        if !synced {
            return provinceId == BabilRegions.seedProvinceId ? all : []
        }
        let inProvince = all.filter { (districts[$0.id]?["provinceId"] as? String) == provinceId }
        if inProvince.isEmpty, provinceId == BabilRegions.seedProvinceId {
            return all
        }
        return inProvince
    }

    /// Governorate id that owns `districtId`, falling back to the seed
    /// province before first sync or when the district is unknown.
    func provinceIdForDistrict(_ districtId: String) -> String {
        if let provinceId = districts[districtId]?["provinceId"] as? String, !provinceId.isEmpty {
            return provinceId
        }
        return BabilRegions.seedProvinceId
    }

    /// True if `point` falls inside any active sub-district's effective
    /// boundary (Admin-drawn polygon, or one synthesized from center + radius).
    func isWithinAnyActiveArea(_ point: CLLocationCoordinate2D) -> Bool {
        for district in districtsForApps {
            for sub in district.subDistricts {
                if GeoPolygon.isWithinBoundary(
                    point: point,
                    center: sub.center,
                    radiusKm: sub.searchRadiusKm,
                    storedBoundary: sub.boundary
                ) {
                    return true
                }
            }
        }
        return false
    }

    func validateForNewRide(
        districtId: String,
        subDistrictId: String,
        pickup: CLLocationCoordinate2D? = nil,
        destination: CLLocationCoordinate2D? = nil
    ) -> String? {
        if !synced {
            let ok = BabilRegions.seedDistricts.contains {
                $0.id == districtId && $0.subDistricts.contains { $0.id == subDistrictId }
            }
            return ok ? nil : "area_inactive"
        }
        guard let district = liveDistricts.first(where: { $0.id == districtId }),
              let sub = district.subDistricts.first(where: { $0.id == subDistrictId })
        else {
            return "area_inactive"
        }
        let others: [GeoArea] = liveDistricts.flatMap { d in
            d.subDistricts.compactMap { other -> GeoArea? in
                guard other.id != sub.id else { return nil }
                return GeoArea(center: other.center, radiusKm: other.searchRadiusKm, boundary: other.boundary)
            }
        }
        func withinSub(_ point: CLLocationCoordinate2D) -> Bool {
            GeoPolygon.isWithinBoundaryUnique(
                point: point,
                center: sub.center,
                radiusKm: sub.searchRadiusKm,
                storedBoundary: sub.boundary,
                others: others
            )
        }
        if let pickup, !withinSub(pickup) {
            return "outside_area"
        }
        if let destination, !withinSub(destination) {
            return "outside_area"
        }
        return nil
    }

    /// Parses a Firestore `boundary` field (array of `{lat, lng}` maps) into
    /// a polygon, or nil when absent/invalid (< 3 points).
    private static func parseBoundary(_ raw: Any?) -> [CLLocationCoordinate2D]? {
        guard let list = raw as? [[String: Any]] else { return nil }
        let points: [CLLocationCoordinate2D] = list.compactMap { entry in
            guard let lat = (entry["lat"] as? NSNumber)?.doubleValue,
                  let lng = (entry["lng"] as? NSNumber)?.doubleValue
            else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return points.count >= 3 ? points : nil
    }

    /// True when the governorate/province is staged for customers (defaults
    /// to visible so existing provinces without the field are unaffected).
    func provinceCustomerVisible(_ provinceId: String) -> Bool {
        guard let data = provinces[provinceId] else { return true }
        return (data["customerVisible"] as? Bool) ?? true
    }

    private func accepts(_ status: String?) -> Bool {
        (status ?? "inactive") == "active"
    }

    private func supportsRide(_ services: [String]) -> Bool {
        services.contains { $0.lowercased() == "ride" }
    }

    private func rebuild() {
        synced = true
        var built: [BabilDistrict] = []
        for (districtId, d) in districts {
            guard accepts(d["status"] as? String) else { continue }
            let provinceId = d["provinceId"] as? String ?? ""
            if let province = provinces[provinceId], !accepts(province["status"] as? String) {
                continue
            }
            let countryId = (provinces[provinceId]?["countryId"] as? String)
                ?? (d["countryId"] as? String)
                ?? ""
            if let country = countries[countryId], !accepts(country["status"] as? String) {
                continue
            }

            let subNodes: [BabilSubDistrict] = subs.compactMap { subId, s in
                guard (s["districtId"] as? String) == districtId else { return nil }
                guard accepts(s["status"] as? String) else { return nil }
                let services = (s["services"] as? [String]) ?? ["ride"]
                guard supportsRide(services) else { return nil }
                let lat = (s["latitude"] as? NSNumber)?.doubleValue ?? 0
                let lng = (s["longitude"] as? NSNumber)?.doubleValue ?? 0
                let radius = (s["searchRadiusKm"] as? NSNumber)?.doubleValue
                    ?? BabilRegions.defaultSubDistrictRadiusKm
                return BabilSubDistrict(
                    id: subId,
                    nameEn: s["nameEn"] as? String ?? subId,
                    nameAr: s["nameAr"] as? String ?? subId,
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    searchRadiusKm: radius,
                    boundary: Self.parseBoundary(s["boundary"])
                )
            }
            .sorted { $0.nameEn < $1.nameEn }

            guard !subNodes.isEmpty else { continue }
            built.append(
                BabilDistrict(
                    id: districtId,
                    nameEn: d["nameEn"] as? String ?? districtId,
                    nameAr: d["nameAr"] as? String ?? districtId,
                    subDistricts: subNodes
                )
            )
        }
        liveDistricts = built.sorted { $0.nameEn < $1.nameEn }
    }
}
