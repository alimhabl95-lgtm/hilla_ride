import CoreLocation
import Foundation

enum GeoMath {
    static func distanceMeters(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let start = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let end = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return start.distance(from: end)
    }

    static func distanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        distanceMeters(from: from, to: to) / 1000.0
    }

    static func estimateDurationMinutes(distanceKm: Double) -> Int {
        max(1, Int((distanceKm / 25.0) * 60.0))
    }
}

enum RideLocationRules {
    static let minTripDistanceMeters = 100.0

    static func areDistinct(_ pickup: CLLocationCoordinate2D, _ destination: CLLocationCoordinate2D) -> Bool {
        GeoMath.distanceMeters(from: pickup, to: destination) >= minTripDistanceMeters
    }
}
