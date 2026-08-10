import CoreLocation
import Foundation

struct BabilSubDistrict: Identifiable, Hashable {
    let id: String
    let nameEn: String
    let nameAr: String
    let center: CLLocationCoordinate2D
    let searchRadiusKm: Double

    func displayName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    static func == (lhs: BabilSubDistrict, rhs: BabilSubDistrict) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
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

    /// True when [point] falls inside the selected sub-district's search radius.
    @MainActor
    static func isWithin(subDistrictId: String, point: CLLocationCoordinate2D) -> Bool {
        guard !subDistrictId.isEmpty else { return false }
        let sub = subDistrict(byId: subDistrictId)
        return GeoMath.distanceKm(from: sub.center, to: point) <= sub.searchRadiusKm
    }

    @MainActor
    static func resolveFromPoint(_ point: CLLocationCoordinate2D) -> (districtId: String, subDistrictId: String) {
        for district in districts {
            for sub in district.subDistricts {
                if GeoMath.distanceKm(from: sub.center, to: point) <= sub.searchRadiusKm {
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
