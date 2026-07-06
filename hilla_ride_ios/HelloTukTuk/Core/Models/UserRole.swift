import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case customer
    case driver
    case manager
    case assistant

    var id: String { rawValue }

    static func fromFirestore(_ value: String?) -> UserRole {
        guard let value, let role = UserRole(rawValue: value) else {
            return .customer
        }
        return role
    }
}

struct AppUser: Identifiable, Equatable {
    let uid: String
    let phone: String
    let role: UserRole
    let name: String
    let age: Int
    let email: String?
    let isBlocked: Bool
    let promoCode: String
    let promoRidesUsed: Int
    let promoRidesLimit: Int

    var id: String { uid }
    var hasPromoRemaining: Bool {
        !promoCode.isEmpty && promoRidesUsed < promoRidesLimit
    }

    init(
        uid: String,
        phone: String,
        role: UserRole,
        name: String,
        age: Int = 18,
        email: String? = nil,
        isBlocked: Bool = false,
        promoCode: String = "",
        promoRidesUsed: Int = 0,
        promoRidesLimit: Int = 0
    ) {
        self.uid = uid
        self.phone = phone
        self.role = role
        self.name = name
        self.age = age
        self.email = email
        self.isBlocked = isBlocked
        self.promoCode = promoCode
        self.promoRidesUsed = promoRidesUsed
        self.promoRidesLimit = promoRidesLimit
    }

    init?(documentID: String, data: [String: Any]) {
        guard let phone = data["phone"] as? String,
              let name = data["name"] as? String else {
            return nil
        }
        uid = documentID
        self.phone = phone
        self.name = name
        role = UserRole.fromFirestore(data["role"] as? String)
        age = data["age"] as? Int ?? 18
        email = data["email"] as? String
        isBlocked = data["isBlocked"] as? Bool ?? false
        promoCode = data["promoCode"] as? String ?? ""
        promoRidesUsed = (data["promoRidesUsed"] as? NSNumber)?.intValue ?? 0
        promoRidesLimit = (data["promoRidesLimit"] as? NSNumber)?.intValue ?? 0
    }
}
