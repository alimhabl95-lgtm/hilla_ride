import CoreLocation
import FirebaseFirestore
import Foundation

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
        listeners.append(db.collection("serviceCountries").addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let snap else { return }
                self.countries = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
        listeners.append(db.collection("serviceProvinces").addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let snap else { return }
                self.provinces = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
        listeners.append(db.collection("serviceDistricts").addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let snap else { return }
                self.districts = Dictionary(
                    uniqueKeysWithValues: snap.documents.map { ($0.documentID, $0.data()) }
                )
                self.rebuild()
            }
        })
        listeners.append(db.collection("serviceSubDistricts").addSnapshotListener { [weak self] snap, _ in
            Task { @MainActor in
                guard let self, let snap else { return }
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
        return visible.isEmpty ? liveDistricts : visible
    }

    func isWithinAnyActiveArea(_ point: CLLocationCoordinate2D) -> Bool {
        for district in districtsForApps {
            for sub in district.subDistricts {
                if GeoMath.distanceKm(from: sub.center, to: point) <= sub.searchRadiusKm {
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
        func withinSub(_ point: CLLocationCoordinate2D) -> Bool {
            GeoMath.distanceKm(from: sub.center, to: point) <= sub.searchRadiusKm
        }
        if let pickup, !withinSub(pickup) {
            return "outside_area"
        }
        if let destination, !withinSub(destination) {
            return "outside_area"
        }
        return nil
    }

    private func accepts(_ status: String?) -> Bool {
        (status ?? "inactive") == "active"
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
                guard services.contains("ride") else { return nil }
                let lat = (s["latitude"] as? NSNumber)?.doubleValue ?? 0
                let lng = (s["longitude"] as? NSNumber)?.doubleValue ?? 0
                let radius = (s["searchRadiusKm"] as? NSNumber)?.doubleValue
                    ?? BabilRegions.defaultSubDistrictRadiusKm
                return BabilSubDistrict(
                    id: subId,
                    nameEn: s["nameEn"] as? String ?? subId,
                    nameAr: s["nameAr"] as? String ?? subId,
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    searchRadiusKm: radius
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
