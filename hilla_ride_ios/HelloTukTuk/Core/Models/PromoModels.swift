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

struct MonthlyPrizeConfig: Equatable {
    let prizeAmountIqd: Int
    let monthKey: String
    let winnerDriverId: String
    let winnerPaid: Bool

    static let defaultPrizeIqd = 50_000

    static func currentMonthKey(from date: Date = Date()) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    init(
        prizeAmountIqd: Int = defaultPrizeIqd,
        monthKey: String = MonthlyPrizeConfig.currentMonthKey(),
        winnerDriverId: String = "",
        winnerPaid: Bool = false
    ) {
        self.prizeAmountIqd = prizeAmountIqd
        self.monthKey = monthKey
        self.winnerDriverId = winnerDriverId
        self.winnerPaid = winnerPaid
    }

    init(data: [String: Any]?) {
        guard let data else {
            self = MonthlyPrizeConfig()
            return
        }
        prizeAmountIqd = (data["prizeAmountIqd"] as? NSNumber)?.intValue ?? Self.defaultPrizeIqd
        monthKey = data["monthKey"] as? String ?? Self.currentMonthKey()
        winnerDriverId = data["winnerDriverId"] as? String ?? ""
        winnerPaid = data["winnerPaid"] as? Bool ?? false
    }
}

struct DriverMonthlyStats: Equatable {
    let rideCount: Int
    let rank: Int
    let totalDrivers: Int
    let prizeAmountIqd: Int
    let monthKey: String
}

final class MonthlyPrizeService {
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

struct MonthlyPrizeConfig: Equatable {
    let prizeAmountIqd: Int
    let monthKey: String
    let winnerDriverId: String
    let winnerPaid: Bool

    static let defaultPrizeIqd = 50_000

    static func currentMonthKey(from date: Date = Date()) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    init(
        prizeAmountIqd: Int = defaultPrizeIqd,
        monthKey: String = MonthlyPrizeConfig.currentMonthKey(),
        winnerDriverId: String = "",
        winnerPaid: Bool = false
    ) {
        self.prizeAmountIqd = prizeAmountIqd
        self.monthKey = monthKey
        self.winnerDriverId = winnerDriverId
        self.winnerPaid = winnerPaid
    }

    init(data: [String: Any]?) {
        guard let data else {
            self = MonthlyPrizeConfig()
            return
        }
        prizeAmountIqd = (data["prizeAmountIqd"] as? NSNumber)?.intValue ?? Self.defaultPrizeIqd
        monthKey = data["monthKey"] as? String ?? Self.currentMonthKey()
        winnerDriverId = data["winnerDriverId"] as? String ?? ""
        winnerPaid = data["winnerPaid"] as? Bool ?? false
    }
}

struct DriverMonthlyStats: Equatable {
    let rideCount: Int
    let rank: Int
    let totalDrivers: Int
    let prizeAmountIqd: Int
    let monthKey: String
}

final class MonthlyPrizeService {
    private let firestore = Firestore.firestore()

    func getConfig() async -> MonthlyPrizeConfig {
        do {
            let doc = try await firestore.collection("config").document("monthly_prize").getDocument()
            return MonthlyPrizeConfig(data: doc.data())
        } catch {
            return MonthlyPrizeConfig()
        }
    }

    func watchDriverStats(driverId: String) -> AsyncStream<DriverMonthlyStats> {
        AsyncStream { continuation in
            let configListener = firestore.collection("config").document("monthly_prize")
                .addSnapshotListener { _, _ in }
            let driversListener = firestore.collection("drivers")
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    Task {
                        let config = await self.getConfig()
                        let stats = self.buildStats(
                            driverId: driverId,
                            config: config,
                            docs: snapshot?.documents ?? []
                        )
                        continuation.yield(stats)
                    }
                }
            continuation.onTermination = { _ in
                configListener.remove()
                driversListener.remove()
            }
        }
    }

    func incrementDriverMonthlyRide(driverId: String) async {
        guard !driverId.isEmpty else { return }
        let monthKey = MonthlyPrizeConfig.currentMonthKey()
        let ref = firestore.collection("drivers").document(driverId)
        let snapshot = try? await ref.getDocument()
        guard let data = snapshot?.data() else { return }
        let currentKey = data["monthlyMonthKey"] as? String ?? ""
        if currentKey != monthKey {
            try? await ref.updateData([
                "monthlyMonthKey": monthKey,
                "monthlyRideCount": 1
            ])
        } else {
            try? await ref.updateData([
                 "monthlyRideCount": FieldValue.increment(Int64(1))
            ])
        }
    }

    private func buildStats(
        driverId: String,
        config: MonthlyPrizeConfig,
        docs: [QueryDocumentSnapshot]
    ) -> DriverMonthlyStats {
        var rows: [(id: String, name: String, count: Int)] = []
        for doc in docs {
            guard let driver = DriverProfile(documentID: doc.documentID, data: doc.data()),
                  driver.isApproved,
                  driver.monthlyMonthKey == config.monthKey,
                  driver.monthlyRideCount > 0 else { continue }
            rows.append((driver.uid, driver.name, driver.monthlyRideCount))
        }
        rows.sort {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let rank = (rows.firstIndex { $0.id == driverId }).map { $0 + 1 }
            ?? (rows.isEmpty ? 1 : rows.count + 1)
        let rideCount = rows.first(where: { $0.id == driverId })?.count ?? 0
        return DriverMonthlyStats(
            rideCount: rideCount,
            rank: rank,
            totalDrivers: rows.count,
            prizeAmountIqd: config.prizeAmountIqd,
            monthKey: config.monthKey
        )
    }
}
