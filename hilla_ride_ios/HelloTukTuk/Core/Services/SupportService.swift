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

struct SupportMessage: Identifiable, Equatable {
    let id: String
    let message: String
    let isFromManager: Bool
    let createdAt: Date?

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        message = data["message"] as? String ?? ""
        isFromManager = data["isFromManager"] as? Bool ?? false
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = nil
        }
        guard !message.isEmpty else { return nil }
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

    func watchUserMessages(userId: String) -> AsyncStream<[SupportMessage]> {
        AsyncStream { continuation in
            // Filter only by userId and sort client-side. Combining a
            // whereField filter with order(by:) would require a composite
            // Firestore index; if it is missing the listener fails silently
            // and no messages appear. Sorting locally matches the Android
            // client and avoids that dependency entirely.
            let listener = firestore.collection("support_messages")
                .whereField("userId", isEqualTo: userId)
                .addSnapshotListener { snapshot, _ in
                    let messages = (snapshot?.documents.compactMap { doc in
                        SupportMessage(documentID: doc.documentID, data: doc.data())
                    } ?? [])
                    .sorted { lhs, rhs in
                        let lhsDate = lhs.createdAt ?? Date(timeIntervalSince1970: 0)
                        let rhsDate = rhs.createdAt ?? Date(timeIntervalSince1970: 0)
                        return lhsDate < rhsDate
                    }
                    continuation.yield(messages)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
