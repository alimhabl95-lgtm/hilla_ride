import CoreLocation
import Foundation

/// Minimal description of a neighboring service area, used only for the
/// nearest-center tie-break in `GeoPolygon.isWithinBoundaryUnique`.
struct GeoArea {
    let center: CLLocationCoordinate2D
    let radiusKm: Double
    let boundary: [CLLocationCoordinate2D]?

    init(center: CLLocationCoordinate2D, radiusKm: Double, boundary: [CLLocationCoordinate2D]? = nil) {
        self.center = center
        self.radiusKm = radiusKm
        self.boundary = boundary
    }
}

struct GeoBoundingBox: Equatable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
}

/// Shared polygon geometry helpers so iOS, Android/Flutter, and Cloud
/// Functions treat the same stored (or synthesized) boundary identically.
enum GeoPolygon {
    private static let earthRadiusKm = 6371.0

    /// Ray-casting point-in-polygon test. `polygon` is an open ring (first
    /// point not repeated at the end). Works directly on lat/lng degrees,
    /// which is an acceptable approximation for the small (sub-district
    /// sized) areas this app operates on.
    static func pointInPolygon(_ point: CLLocationCoordinate2D, _ polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        let x = point.longitude
        let y = point.latitude
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            let intersects = (yi > y) != (yj > y) &&
                x < (xj - xi) * (y - yi) / (yj - yi) + xi
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Builds a regular `sides`-gon polygon approximating a circle of
    /// `radiusKm` centered at `center`. Used as a temporary boundary for
    /// sub-districts that don't yet have an Admin-drawn polygon.
    static func syntheticPolygonFromCircle(
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        sides: Int = 16
    ) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        for i in 0..<sides {
            let bearingDeg = (360.0 / Double(sides)) * Double(i)
            points.append(destinationPoint(start: center, distanceKm: radiusKm, bearingDeg: bearingDeg))
        }
        return points
    }

    /// Maximum distance (km) from `center` to any vertex of `polygon`.
    /// Used to size a Google Places location bias so it covers the whole
    /// effective boundary, not just the raw stored radius.
    static func boundingRadiusKm(center: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Double {
        guard !polygon.isEmpty else { return 0 }
        var maxKm = 0.0
        for p in polygon {
            let km = distanceKm(center, p)
            if km > maxKm { maxKm = km }
        }
        return maxKm
    }

    /// Resolves the effective boundary for an area: the stored polygon when
    /// present (>= 3 points), otherwise a synthesized polygon from
    /// center + radius. This is the single place that decides "real polygon
    /// vs. temporary circle-derived polygon" — every call site upgrades
    /// automatically the moment Admin draws a real boundary.
    static func effectiveBoundary(
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        storedBoundary: [CLLocationCoordinate2D]?
    ) -> [CLLocationCoordinate2D] {
        if let stored = storedBoundary, stored.count >= 3 {
            return stored
        }
        return syntheticPolygonFromCircle(center: center, radiusKm: radiusKm)
    }

    /// Axis-aligned bounding box for the effective service-area boundary.
    static func boundingBox(
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        storedBoundary: [CLLocationCoordinate2D]?
    ) -> GeoBoundingBox {
        let polygon = effectiveBoundary(
            center: center,
            radiusKm: radiusKm,
            storedBoundary: storedBoundary
        )
        guard let first = polygon.first else {
            let delta = max(0.01, radiusKm / 111.0)
            return GeoBoundingBox(
                south: center.latitude - delta,
                west: center.longitude - delta,
                north: center.latitude + delta,
                east: center.longitude + delta
            )
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in polygon {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        return GeoBoundingBox(south: minLat, west: minLon, north: maxLat, east: maxLon)
    }

    /// True when `point` falls inside the effective boundary of an area
    /// described by `center` + `radiusKm` (+ optional `storedBoundary`).
    static func isWithinBoundary(
        point: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        storedBoundary: [CLLocationCoordinate2D]?
    ) -> Bool {
        let boundary = effectiveBoundary(center: center, radiusKm: radiusKm, storedBoundary: storedBoundary)
        return pointInPolygon(point, boundary)
    }

    /// True when `point` belongs to this area specifically, resolving the
    /// ambiguity that arises when two *temporary* circle boundaries (no
    /// Admin-drawn polygon yet) overlap — e.g. Qasim and Al-Shumali are both
    /// large synthesized circles inside the same district. In that overlap
    /// case the point is assigned to whichever area's center is nearest, so
    /// a point clearly inside Qasim never also counts as "inside" Al-Shumali
    /// just because the circles overlap. An Admin-drawn polygon (on this
    /// area or a neighboring one) is always authoritative and skips the
    /// tie-break entirely.
    static func isWithinBoundaryUnique(
        point: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        storedBoundary: [CLLocationCoordinate2D]?,
        others: [GeoArea] = []
    ) -> Bool {
        guard isWithinBoundary(point: point, center: center, radiusKm: radiusKm, storedBoundary: storedBoundary) else {
            return false
        }
        if let stored = storedBoundary, stored.count >= 3 { return true }

        let selfDistanceKm = distanceKm(center, point)
        for other in others {
            if let otherBoundary = other.boundary, otherBoundary.count >= 3 {
                if pointInPolygon(point, otherBoundary) { return false }
                continue
            }
            let otherInside = isWithinBoundary(
                point: point,
                center: other.center,
                radiusKm: other.radiusKm,
                storedBoundary: nil
            )
            guard otherInside else { continue }
            if distanceKm(other.center, point) < selfDistanceKm { return false }
        }
        return true
    }

    private static func distanceKm(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLat = deg2rad(b.latitude - a.latitude)
        let dLng = deg2rad(b.longitude - a.longitude)
        let lat1 = deg2rad(a.latitude)
        let lat2 = deg2rad(b.latitude)
        let sinDLat = sin(dLat / 2)
        let sinDLng = sin(dLng / 2)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLng * sinDLng
        return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h))
    }

    private static func destinationPoint(
        start: CLLocationCoordinate2D,
        distanceKm: Double,
        bearingDeg: Double
    ) -> CLLocationCoordinate2D {
        let d = distanceKm / earthRadiusKm
        let brng = deg2rad(bearingDeg)
        let lat1 = deg2rad(start.latitude)
        let lon1 = deg2rad(start.longitude)

        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng))
        let lon2 = lon1 + atan2(
            sin(brng) * sin(d) * cos(lat1),
            cos(d) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(latitude: rad2deg(lat2), longitude: rad2deg(lon2))
    }

    private static func deg2rad(_ deg: Double) -> Double { deg * .pi / 180.0 }
    private static func rad2deg(_ rad: Double) -> Double { rad * 180.0 / .pi }
}
