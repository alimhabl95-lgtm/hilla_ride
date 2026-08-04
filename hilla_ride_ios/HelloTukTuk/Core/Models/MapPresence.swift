import CoreLocation
import FirebaseFirestore
import Foundation

struct MapPresence: Identifiable, Equatable {
    let providerId: String
    let serviceType: String
    let status: DriverOperationalStatus
    let latitude: Double
    let longitude: Double
    let heading: Double
    let geohash: String
    let vehicleType: String
    let displayName: String
    let photoUrl: String
    let rating: Double
    let phone: String
    let locationUpdatedAt: Date?

    var id: String { providerId }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isFresh: Bool {
        guard let locationUpdatedAt else { return false }
        return Date().timeIntervalSince(locationUpdatedAt) <= MapPresenceConfig.staleLocationCutoffSeconds
    }

    var isVisibleOnCustomerMap: Bool {
        status.appearsOnCustomerMap
            && isFresh
            && serviceType == MapPresenceConfig.serviceTypeRide
    }

    init?(documentID: String, data: [String: Any]) {
        let lat = (data["latitude"] as? NSNumber)?.doubleValue
        let lng = (data["longitude"] as? NSNumber)?.doubleValue
        guard let lat, let lng else { return nil }
        providerId = data["providerId"] as? String ?? documentID
        serviceType = data["serviceType"] as? String ?? MapPresenceConfig.serviceTypeRide
        status = DriverOperationalStatus(rawValue: data["status"] as? String ?? "offline") ?? .offline
        latitude = lat
        longitude = lng
        heading = (data["heading"] as? NSNumber)?.doubleValue ?? 0
        geohash = data["geohash"] as? String ?? ""
        vehicleType = data["vehicleType"] as? String ?? MapPresenceConfig.vehicleTypeTukTuk
        displayName = data["displayName"] as? String ?? ""
        photoUrl = data["photoUrl"] as? String ?? ""
        rating = (data["rating"] as? NSNumber)?.doubleValue ?? 5
        phone = data["phone"] as? String ?? ""
        if let ts = data["locationUpdatedAt"] as? Timestamp {
            locationUpdatedAt = ts.dateValue()
        } else {
            locationUpdatedAt = nil
        }
    }
}
