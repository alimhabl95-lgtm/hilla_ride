import Foundation

enum Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int = 6) -> String {
        var latMin = -90.0
        var latMax = 90.0
        var lngMin = -180.0
        var lngMax = 180.0
        var hash = ""
        var bit = 0
        var ch = 0
        var isLng = true

        while hash.count < precision {
            if isLng {
                let mid = (lngMin + lngMax) / 2
                if longitude >= mid {
                    ch = (ch << 1) + 1
                    lngMin = mid
                } else {
                    ch <<= 1
                    lngMax = mid
                }
            } else {
                let mid = (latMin + latMax) / 2
                if latitude >= mid {
                    ch = (ch << 1) + 1
                    latMin = mid
                } else {
                    ch <<= 1
                    latMax = mid
                }
            }
            isLng.toggle()
            bit += 1
            if bit == 5 {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return hash
    }

    static func searchPrefixes(latitude: Double, longitude: Double) -> [String] {
        let center = encode(latitude: latitude, longitude: longitude, precision: 6)
        guard center.count >= 2 else { return [center] }
        let parent = String(center.dropLast())
        let lastChar = center.last!
        guard let index = base32.firstIndex(of: lastChar) else { return [center] }
        let idx = base32.distance(from: base32.startIndex, to: index)
        var prefixes: Set<String> = [center, parent]
        if idx > 0 { prefixes.insert(parent + String(base32[idx - 1])) }
        if idx < base32.count - 1 { prefixes.insert(parent + String(base32[idx + 1])) }
        return Array(prefixes)
    }

    static func upperBound(_ prefix: String) -> String {
        prefix + "\u{f8ff}"
    }
}
