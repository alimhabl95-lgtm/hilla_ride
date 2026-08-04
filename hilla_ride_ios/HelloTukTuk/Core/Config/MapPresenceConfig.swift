import CoreLocation
import Foundation

enum MapPresenceConfig {
    static let collection = "mapPresence"
    static let serviceTypeRide = "ride"
    static let vehicleTypeTukTuk = "tukTuk"
    static let nearbyRadiusKm = 3.0
    static let maxNearbyMarkers = 20
    static let staleLocationCutoffSeconds: TimeInterval = 60
    static let locationPublishMinInterval: TimeInterval = 3
    static let locationPublishMinMoveMeters: CLLocationDistance = 10
    static let markerAnimationDuration: TimeInterval = 0.9
    static let routeRefreshInterval: TimeInterval = 18
}

enum DriverOperationalStatus: String {
    case available
    case searching
    case rideOffered
    case rideAccepted
    case arrivingPickup
    case onTrip
    case completed
    case offline

    var appearsOnCustomerMap: Bool { self == .available }
}
