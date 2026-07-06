import FirebaseFirestore
import Foundation

struct SupportContactInfo {
    let phone: String
    let whatsapp: String
    let email: String

    static let defaults = SupportContactInfo(
        phone: "+9647735349061",
        whatsapp: "+9647735349061",
        email: "hellotuktuk3@gmail.com"
    )

    init(phone: String, whatsapp: String, email: String) {
        self.phone = phone
        self.whatsapp = whatsapp
        self.email = email
    }

    init(data: [String: Any]?) {
        phone = data?["phone"] as? String ?? Self.defaults.phone
        whatsapp = data?["whatsapp"] as? String ?? Self.defaults.whatsapp
        email = data?["email"] as? String ?? Self.defaults.email
    }
}

final class SupportService {
    private let firestore = Firestore.firestore()

    func getContactInfo() async -> SupportContactInfo {
        do {
            let doc = try await firestore.collection("config").document("support").getDocument()
            return SupportContactInfo(data: doc.data())
        } catch {
            return .defaults
        }
    }

    func sendMessage(
        userId: String,
        userRole: UserRole,
        userName: String,
        phone: String,
        message: String
    ) async throws {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await firestore.collection("support_messages").document(UUID().uuidString).setData([
            "userId": userId,
            "userRole": userRole.rawValue,
            "userName": userName,
            "phone": phone,
            "message": trimmed,
            "isFromManager": false,
            "status": "open",
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}
