import CoreLocation
import Foundation
struct BabilSubDistrict: Identifiable, Hashable, Equatable {
    let id: String
    let nameEn: String
    let nameAr: String
    let center: CLLocationCoordinate2D
    let searchRadiusKm: Double

    func displayName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }
}

struct BabilDistrict: Identifiable {
    let id: String
    let nameEn: String
    let nameAr: String
    let subDistricts: [BabilSubDistrict]

    func displayName(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
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
}
