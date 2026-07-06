import FirebaseFirestore
import Foundation

struct PromoCodeConfig {
    let code: String
    let enabled: Bool
    let discountPercent: Int
    let maxDiscountIqd: Int
    let maxRides: Int

    static let free3Defaults = PromoCodeConfig(
        code: "FREE3",
        enabled: true,
        discountPercent: 50,
        maxDiscountIqd: 1000,
        maxRides: 2
    )

    init(code: String, enabled: Bool, discountPercent: Int, maxDiscountIqd: Int, maxRides: Int) {
        self.code = code
        self.enabled = enabled
        self.discountPercent = discountPercent
        self.maxDiscountIqd = maxDiscountIqd
        self.maxRides = maxRides
    }

    init?(data: [String: Any]?) {
        guard let data else {
            self = .free3Defaults
            return
        }
        code = data["code"] as? String ?? PromoCodeConfig.free3Defaults.code
        enabled = data["enabled"] as? Bool ?? true
        discountPercent = (data["discountPercent"] as? NSNumber)?.intValue ?? 50
        maxDiscountIqd = (data["maxDiscountIqd"] as? NSNumber)?.intValue ?? 1000
        maxRides = (data["maxRides"] as? NSNumber)?.intValue ?? 2
    }
}

struct PromoApplication {
    let baseFareIqd: Int
    let discountIqd: Int
    let finalFareIqd: Int
    let promoCode: String

    var hasDiscount: Bool { discountIqd > 0 && !promoCode.isEmpty }
}

final class PromoService {
    private let firestore = Firestore.firestore()

    func getPromoCode(_ code: String) async -> PromoCodeConfig {
        do {
            let doc = try await firestore.collection("config").document("promo_\(code)").getDocument()
            return PromoCodeConfig(data: doc.data()) ?? .free3Defaults
        } catch {
            return .free3Defaults
        }
    }

    func applyPromo(user: AppUser, config: PromoCodeConfig, baseFareIqd: Int) -> PromoApplication {
        guard baseFareIqd > 0,
              config.enabled,
              user.promoCode == config.code,
              user.promoRidesUsed < user.promoRidesLimit else {
            return PromoApplication(
                baseFareIqd: baseFareIqd,
                discountIqd: 0,
                finalFareIqd: baseFareIqd,
                promoCode: ""
            )
        }

        let rawDiscount = Int((Double(baseFareIqd) * Double(config.discountPercent) / 100.0).rounded())
        let discount = min(max(rawDiscount, 0), config.maxDiscountIqd)
        let finalFare = max(baseFareIqd - discount, 0)
        return PromoApplication(
            baseFareIqd: baseFareIqd,
            discountIqd: discount,
            finalFareIqd: finalFare,
            promoCode: config.code
        )
    }
}
