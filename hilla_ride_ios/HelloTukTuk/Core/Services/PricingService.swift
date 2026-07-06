import CoreLocation
import FirebaseFirestore
import Foundation

final class PricingService {
    private let firestore = Firestore.firestore()
    private var cache: [String: PricingConfig] = [:]

    func quoteRide(
        pickup: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        districtId: String,
        subDistrictId: String
    ) async -> RideQuote {
        guard RideLocationRules.areDistinct(pickup, destination) else {
            return RideQuote(distanceKm: 0, durationMinutes: 0, fareIqd: nil, outOfService: true)
        }

        let config = await loadConfig(districtId: districtId, subDistrictId: subDistrictId)
        let distanceKm = GeoMath.distanceKm(from: pickup, to: destination)
        let durationMinutes = GeoMath.estimateDurationMinutes(distanceKm: distanceKm)
        return quoteFromDistanceKm(distanceKm, config: config, durationMinutes: durationMinutes)
    }

    func quoteFromDistanceKm(
        _ distanceKm: Double,
        config: PricingConfig,
        durationMinutes: Int
    ) -> RideQuote {
        if distanceKm > config.maxDistanceKm {
            return RideQuote(
                distanceKm: distanceKm,
                durationMinutes: durationMinutes,
                fareIqd: nil,
                outOfService: true
            )
        }

        for bracket in config.brackets {
            if distanceKm >= bracket.minKm && distanceKm <= bracket.maxKm {
                return RideQuote(
                    distanceKm: distanceKm,
                    durationMinutes: durationMinutes,
                    fareIqd: bracket.priceIqd,
                    outOfService: false
                )
            }
        }

        return RideQuote(
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            fareIqd: nil,
            outOfService: true
        )
    }

    private func loadConfig(districtId: String, subDistrictId: String) async -> PricingConfig {
        let cacheKey = "\(districtId)|\(subDistrictId)"
        if let cached = cache[cacheKey] {
            return cached
        }

        let subDocId = "pricing_\(districtId)_\(subDistrictId)"
        if let subDoc = try? await firestore.collection("config").document(subDocId).getDocument(),
           let data = subDoc.data(),
           let config = PricingConfig(data: data) {
            cache[cacheKey] = config
            return config
        }

        let districtDocId = "pricing_\(districtId)"
        if let districtDoc = try? await firestore.collection("config").document(districtDocId).getDocument(),
           let data = districtDoc.data(),
           let config = PricingConfig(data: data) {
            cache[cacheKey] = config
            return config
        }

        cache[cacheKey] = .defaults
        return .defaults
    }
}
