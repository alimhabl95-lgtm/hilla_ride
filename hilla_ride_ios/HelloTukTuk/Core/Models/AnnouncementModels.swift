import FirebaseFirestore
import Foundation

struct Announcement: Identifiable, Equatable {
    let id: String
    let audience: String
    let title: String
    let body: String
    let createdAt: Date?

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        audience = data["audience"] as? String ?? ""
        title = data["title"] as? String ?? ""
        body = data["body"] as? String ?? ""
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = nil
        }
        guard !title.isEmpty else { return nil }
    }
}
