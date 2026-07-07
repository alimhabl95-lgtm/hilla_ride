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

    // CLLocationCoordinate2D is not Hashable/Equatable, so conform by unique id.
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
    static let customerDistrictId = "hashimiya"
    static let defaultSubDistrictRadiusKm = 22.0

    static let districts: [BabilDistrict] = [
        BabilDistrict(
            id: customerDistrictId,
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

    static var customerDistrict: BabilDistrict {
        districts.first { $0.id == customerDistrictId } ?? districts[0]
    }

    static func subDistrict(byId id: String) -> BabilSubDistrict {
        customerDistrict.subDistricts.first { $0.id == id } ?? customerDistrict.subDistricts[0]
    }

    /// True when [point] falls inside the selected sub-district's search radius.
    /// Used to keep search results scoped to the chosen area only.
    static func isWithin(subDistrictId: String, point: CLLocationCoordinate2D) -> Bool {
        guard !subDistrictId.isEmpty else { return false }
        let sub = subDistrict(byId: subDistrictId)
        return GeoMath.distanceKm(from: sub.center, to: point) <= sub.searchRadiusKm
    }
}
