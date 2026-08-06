import FirebaseFirestore
import Foundation

struct Announcement: Identifiable, Equatable {
    let id: String
    let audience: String
    let title: String
    let body: String
    let createdAt: Date?
    let showAsBanner: Bool

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
        let bannerFlag = data["showAsBanner"]
        if let boolFlag = bannerFlag as? Bool {
            showAsBanner = boolFlag
        } else if let intFlag = bannerFlag as? Int {
            showAsBanner = intFlag != 0
        } else {
            showAsBanner = false
        }
        guard !title.isEmpty else { return nil }
    }
}
