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

    var id: String { uid }
    var isApproved: Bool { approvalStatus == .approved }

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
    }
}
