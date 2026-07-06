import FirebaseFirestore
import Foundation

final class UserRepository {
    private let firestore = Firestore.firestore()

    func fetchUser(uid: String) async throws -> AppUser? {
        let doc = try await firestore.collection("users").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return AppUser(documentID: doc.documentID, data: data)
    }

    func customerPromoFields() async -> [String: Any] {
        do {
            let doc = try await firestore.collection("config").document("promo_FREE3").getDocument()
            if let data = doc.data(),
               let enabled = data["enabled"] as? Bool, enabled,
               let autoAssign = data["autoAssignOnSignup"] as? Bool, autoAssign,
               let code = data["code"] as? String,
               let maxRides = data["maxRides"] as? Int {
                return [
                    "promoCode": code,
                    "promoRidesUsed": 0,
                    "promoRidesLimit": maxRides
                ]
            }
        } catch {
            // Fall back to defaults used by the Flutter app.
        }

        return [
            "promoCode": "FREE3",
            "promoRidesUsed": 0,
            "promoRidesLimit": 3
        ]
    }

    func createUserProfile(
        uid: String,
        phone: String,
        role: UserRole,
        fullName: String,
        email: String?,
        age: Int
    ) async throws {
        let docRef = firestore.collection("users").document(uid)
        let existing = try await docRef.getDocument()
        if existing.exists, existing.data() != nil {
            return
        }

        var payload: [String: Any] = [
            "phone": phone,
            "role": role.rawValue,
            "name": fullName,
            "age": age,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["email"] = email.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if role == .customer {
            payload.merge(await customerPromoFields()) { _, new in new }
        }

        try await docRef.setData(payload)

        let phoneKey = phone.filter(\.isNumber)
        if !phoneKey.isEmpty {
            try? await firestore.collection("released_phones").document(phoneKey).delete()
        }
    }

    func updateUserName(uid: String, name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try await firestore.collection("users").document(uid).updateData([
            "name": trimmed
        ])
    }
}
