import FirebaseFirestore
import Foundation

struct RideMessage: Identifiable, Equatable {
    let id: String
    let senderId: String
    let senderRole: UserRole
    let senderName: String
    let text: String
    let createdAt: Date?

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        senderId = data["senderId"] as? String ?? ""
        senderName = data["senderName"] as? String ?? ""
        text = data["text"] as? String ?? ""
        senderRole = UserRole.fromFirestore(data["senderRole"] as? String)
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = nil
        }
    }
}

final class ChatService {
    private let firestore = Firestore.firestore()

    func watchRideMessages(rideId: String) -> AsyncStream<[RideMessage]> {
        AsyncStream { continuation in
            let listener = firestore.collection("rides").document(rideId)
                .collection("messages")
                .order(by: "createdAt", descending: false)
                .addSnapshotListener { snapshot, _ in
                    let messages = snapshot?.documents.compactMap {
                        RideMessage(documentID: $0.documentID, data: $0.data())
                    } ?? []
                    continuation.yield(messages)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func sendRideMessage(
        rideId: String,
        senderId: String,
        senderRole: UserRole,
        senderName: String,
        text: String
    ) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await firestore.collection("rides").document(rideId)
            .collection("messages")
            .document(UUID().uuidString)
            .setData([
                "senderId": senderId,
                "senderRole": senderRole.rawValue,
                "senderName": senderName,
                "text": trimmed,
                "type": "text",
                "createdAt": FieldValue.serverTimestamp()
            ])
    }
}
