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

    var id: String { uid }

    init(uid: String, phone: String, role: UserRole, name: String, age: Int = 18, email: String? = nil, isBlocked: Bool = false) {
        self.uid = uid
        self.phone = phone
        self.role = role
        self.name = name
        self.age = age
        self.email = email
        self.isBlocked = isBlocked
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
    }
}
