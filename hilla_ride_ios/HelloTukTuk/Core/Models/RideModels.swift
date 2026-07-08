import CoreLocation
import FirebaseFirestore
import Foundation

enum RideStatus: String, Codable, CaseIterable {
    case searching
    case matched
    case accepted
    case inProgress
    case awaitingCashPayment
    case completed
    case cancelled

    static let activeCustomerStatuses: [String] = [
        RideStatus.searching.rawValue,
        RideStatus.matched.rawValue,
        RideStatus.accepted.rawValue,
        RideStatus.inProgress.rawValue,
        RideStatus.awaitingCashPayment.rawValue
    ]

    static func fromFirestore(_ value: String?) -> RideStatus {
        guard let value, let status = RideStatus(rawValue: value) else {
            return .searching
        }
        return status
    }
}

struct MapPlace: Identifiable, Equatable, Hashable {
    let id = UUID()
    let label: String
    let coordinate: CLLocationCoordinate2D

    var latitude: Double { coordinate.latitude }
    var longitude: Double { coordinate.longitude }

    static func == (lhs: MapPlace, rhs: MapPlace) -> Bool {
        lhs.label == rhs.label &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

struct Ride: Identifiable, Equatable {
    let id: String
    let customerId: String
    let driverId: String?
    let pickupLabel: String
    let destinationLabel: String
    let pickupLat: Double
    let pickupLng: Double
    let destinationLat: Double
    let destinationLng: Double
    let status: RideStatus
    let fareAmountIqd: Int
    let districtId: String
    let subDistrictId: String
    let distanceKm: Double
    let offeredDriverIds: [String]
    let driverRating: Int?
    let driverEarningsIqd: Int
    let promoDiscountIqd: Int
    let rideNumber: String
    let createdAt: Date?
    let completedAt: Date?

    var pickupCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pickupLat, longitude: pickupLng)
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLng)
    }

    init?(
        documentID: String,
        data: [String: Any]
    ) {
        guard let customerId = data["customerId"] as? String else { return nil }
        id = documentID
        self.customerId = customerId
        driverId = data["driverId"] as? String
        pickupLabel = data["pickupLabel"] as? String ?? ""
        destinationLabel = data["destinationLabel"] as? String ?? ""
        pickupLat = (data["pickupLat"] as? NSNumber)?.doubleValue ?? 0
        pickupLng = (data["pickupLng"] as? NSNumber)?.doubleValue ?? 0
        destinationLat = (data["destinationLat"] as? NSNumber)?.doubleValue ?? 0
        destinationLng = (data["destinationLng"] as? NSNumber)?.doubleValue ?? 0
        status = RideStatus.fromFirestore(data["status"] as? String)
        fareAmountIqd = (data["fareAmountIqd"] as? NSNumber)?.intValue ?? 0
        districtId = data["districtId"] as? String ?? ""
        subDistrictId = data["subDistrictId"] as? String ?? ""
        distanceKm = (data["distanceKm"] as? NSNumber)?.doubleValue ?? 0
        offeredDriverIds = (data["offeredDriverIds"] as? [String]) ?? []
        driverRating = (data["driverRating"] as? NSNumber)?.intValue
        driverEarningsIqd = (data["driverEarningsIqd"] as? NSNumber)?.intValue ?? 0
        promoDiscountIqd = (data["promoDiscountIqd"] as? NSNumber)?.intValue ?? 0
        rideNumber = data["rideNumber"] as? String ?? ""
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = nil
        }
        if let timestamp = data["completedAt"] as? Timestamp {
            completedAt = timestamp.dateValue()
        } else {
            completedAt = nil
        }
    }
}
