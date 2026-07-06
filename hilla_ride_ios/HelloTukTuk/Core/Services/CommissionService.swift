import FirebaseFirestore
import Foundation

struct FareSplit {
    let fareIqd: Int
    let commissionPercent: Double
    let platformCommissionIqd: Int
    let driverEarningsIqd: Int
}

final class CommissionService {
    private let firestore = Firestore.firestore()
    private static let defaultPlatformPercent = 10.0

    func getConfig() async -> Double {
        do {
            let doc = try await firestore.collection("config").document("commission").getDocument()
            guard let data = doc.data(),
                  let percent = (data["platformPercent"] as? NSNumber)?.doubleValue else {
                return Self.defaultPlatformPercent
            }
            return percent
        } catch {
            return Self.defaultPlatformPercent
        }
    }

    func splitFare(fareIqd: Int, platformPercent: Double) -> FareSplit {
        let clamped = min(max(platformPercent, 0), 100)
        let commission = Int((Double(fareIqd) * clamped / 100.0).rounded())
        return FareSplit(
            fareIqd: fareIqd,
            commissionPercent: clamped,
            platformCommissionIqd: commission,
            driverEarningsIqd: fareIqd - commission
        )
    }
}
