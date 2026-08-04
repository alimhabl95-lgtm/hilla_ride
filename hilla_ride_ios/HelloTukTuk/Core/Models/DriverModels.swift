import CoreLocation
import Foundation

enum DriverApprovalStatus: String, Codable {
    case pending
    case approved
    case rejected

    static func fromFirestore(_ value: String?) -> DriverApprovalStatus {
        guard let value, let status = DriverApprovalStatus(rawValue: value) else {
            return .pending
        }
        return status
    }
}

struct DriverProfile: Identifiable, Equatable {
    let uid: String
    let phone: String
    let name: String
    let vehicleType: String
    let vehiclePlate: String
    let vehicleColor: String
    let profilePhotoUrl: String
    let rating: Double
    let approvalStatus: DriverApprovalStatus
    let isBlocked: Bool
    let isOnline: Bool
    let latitude: Double?
    let longitude: Double?
    let heading: Double
    let operationalStatus: String
    let hasActiveRide: Bool
    let isFakeDriver: Bool
    let autoAcceptRides: Bool
    let assignedDistrictId: String
    let assignedSubDistrictId: String
    let completedRidesCount: Int
    let totalDriverEarningsIqd: Int
    let outstandingDriverEarningsIqd: Int
    let outstandingPlatformCommissionIqd: Int
    let pendingBonusIqd: Int
    let monthlyRideCount: Int
    let monthlyMonthKey: String
    let walletBalanceIqd: Int
    let walletStatus: String

    var id: String { uid }
    var isApproved: Bool { approvalStatus == .approved }
    var hasAssignedWorkArea: Bool {
        !assignedDistrictId.isEmpty && !assignedSubDistrictId.isEmpty
    }

    var walletAllowsMatching: Bool {
        walletStatus != "blocked" && walletBalanceIqd > 0
    }

    func walletAllowsMatching(minBalanceIqd: Int) -> Bool {
        let minBalance = max(minBalanceIqd, 1)
        return walletStatus != "blocked"
            && walletBalanceIqd > 0
            && walletBalanceIqd >= minBalance
    }

    var sortCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init?(documentID: String, data: [String: Any]) {
        guard let phone = data["phone"] as? String,
              let name = data["name"] as? String else {
            return nil
        }
        uid = documentID
        self.phone = phone
        self.name = name
        vehicleType = data["vehicleType"] as? String ?? "Tuk-Tuk"
        vehiclePlate = data["vehiclePlate"] as? String ?? ""
        vehicleColor = data["vehicleColor"] as? String ?? ""
        profilePhotoUrl = data["profilePhotoUrl"] as? String ?? ""
        rating = (data["rating"] as? NSNumber)?.doubleValue ?? 5.0
        approvalStatus = DriverApprovalStatus.fromFirestore(data["approvalStatus"] as? String)
        isBlocked = data["isBlocked"] as? Bool ?? false
        isOnline = data["isOnline"] as? Bool ?? false
        latitude = (data["latitude"] as? NSNumber)?.doubleValue
        longitude = (data["longitude"] as? NSNumber)?.doubleValue
        heading = (data["heading"] as? NSNumber)?.doubleValue ?? 0
        if let status = data["operationalStatus"] as? String, !status.isEmpty {
            operationalStatus = status
        } else if isOnline {
            operationalStatus = (data["hasActiveRide"] as? Bool ?? false)
                ? DriverOperationalStatus.arrivingPickup.rawValue
                : DriverOperationalStatus.available.rawValue
        } else {
            operationalStatus = DriverOperationalStatus.offline.rawValue
        }
        hasActiveRide = data["hasActiveRide"] as? Bool ?? false
        isFakeDriver = data["isFakeDriver"] as? Bool ?? false
        autoAcceptRides = data["autoAcceptRides"] as? Bool ?? false
        assignedDistrictId = data["assignedDistrictId"] as? String ?? ""
        assignedSubDistrictId = data["assignedSubDistrictId"] as? String ?? ""
        completedRidesCount = (data["completedRidesCount"] as? NSNumber)?.intValue ?? 0
        totalDriverEarningsIqd = (data["totalDriverEarningsIqd"] as? NSNumber)?.intValue ?? 0
        if let outstandingDriver = data["outstandingDriverEarningsIqd"] as? NSNumber {
            outstandingDriverEarningsIqd = outstandingDriver.intValue
        } else {
            outstandingDriverEarningsIqd = (data["totalDriverEarningsIqd"] as? NSNumber)?.intValue ?? 0
        }
        outstandingPlatformCommissionIqd = (data["outstandingPlatformCommissionIqd"] as? NSNumber)?.intValue ?? 0
        pendingBonusIqd = (data["pendingBonusIqd"] as? NSNumber)?.intValue ?? 0
        monthlyRideCount = (data["monthlyRideCount"] as? NSNumber)?.intValue ?? 0
        monthlyMonthKey = data["monthlyMonthKey"] as? String ?? ""
        walletBalanceIqd = (data["walletBalanceIqd"] as? NSNumber)?.intValue ?? 0
        if let status = data["walletStatus"] as? String, !status.isEmpty {
            walletStatus = status
        } else {
            walletStatus = walletBalanceIqd > 0 ? "active" : "blocked"
        }
    }
}
