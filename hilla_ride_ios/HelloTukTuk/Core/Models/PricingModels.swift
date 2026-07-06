import Foundation

struct PricingBracket {
    let minKm: Double
    let maxKm: Double
    let priceIqd: Int

    init?(data: [String: Any]) {
        guard let minKm = (data["minKm"] as? NSNumber)?.doubleValue,
              let maxKm = (data["maxKm"] as? NSNumber)?.doubleValue,
              let priceIqd = (data["priceIqd"] as? NSNumber)?.intValue else {
            return nil
        }
        self.minKm = minKm
        self.maxKm = maxKm
        self.priceIqd = priceIqd
    }
}

struct PricingConfig {
    let maxDistanceKm: Double
    let brackets: [PricingBracket]

    static let defaults = PricingConfig(
        maxDistanceKm: 5.0,
        brackets: [
            PricingBracket(minKm: 0, maxKm: 1.25, priceIqd: 1000),
            PricingBracket(minKm: 1.26, maxKm: 2.0, priceIqd: 2000),
            PricingBracket(minKm: 2.01, maxKm: 3.5, priceIqd: 3000),
            PricingBracket(minKm: 3.51, maxKm: 5.0, priceIqd: 5000)
        ]
    )

    init(maxDistanceKm: Double, brackets: [PricingBracket]) {
        self.maxDistanceKm = maxDistanceKm
        self.brackets = brackets
    }

    init?(data: [String: Any]) {
        let maxDistanceKm = (data["maxDistanceKm"] as? NSNumber)?.doubleValue ?? 5.0
        let raw = data["brackets"] as? [[String: Any]] ?? []
        let brackets = raw.compactMap(PricingBracket.init(data:))
        guard !brackets.isEmpty else { return nil }
        self.maxDistanceKm = maxDistanceKm
        self.brackets = brackets
    }
}

private extension PricingBracket {
    init(minKm: Double, maxKm: Double, priceIqd: Int) {
        self.minKm = minKm
        self.maxKm = maxKm
        self.priceIqd = priceIqd
    }
}

struct RideQuote {
    let distanceKm: Double
    let durationMinutes: Int
    let fareIqd: Int?
    let outOfService: Bool

    var canBook: Bool {
        !outOfService && fareIqd != nil
    }
}
