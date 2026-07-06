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
    let approvalStatus: DriverApprovalStatus
    let isBlocked: Bool
    let isOnline: Bool
    let latitude: Double?
    let longitude: Double?
    let hasActiveRide: Bool
    let isFakeDriver: Bool
    let autoAcceptRides: Bool
    let assignedDistrictId: String
    let assignedSubDistrictId: String
    let completedRidesCount: Int

    var id: String { uid }
    var isApproved: Bool { approvalStatus == .approved }
    var hasAssignedWorkArea: Bool {
        !assignedDistrictId.isEmpty && !assignedSubDistrictId.isEmpty
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
        approvalStatus = DriverApprovalStatus.fromFirestore(data["approvalStatus"] as? String)
        isBlocked = data["isBlocked"] as? Bool ?? false
        isOnline = data["isOnline"] as? Bool ?? false
        latitude = (data["latitude"] as? NSNumber)?.doubleValue
        longitude = (data["longitude"] as? NSNumber)?.doubleValue
        hasActiveRide = data["hasActiveRide"] as? Bool ?? false
        isFakeDriver = data["isFakeDriver"] as? Bool ?? false
        autoAcceptRides = data["autoAcceptRides"] as? Bool ?? false
        assignedDistrictId = data["assignedDistrictId"] as? String ?? ""
        assignedSubDistrictId = data["assignedSubDistrictId"] as? String ?? ""
        completedRidesCount = (data["completedRidesCount"] as? NSNumber)?.intValue ?? 0
    }
}
