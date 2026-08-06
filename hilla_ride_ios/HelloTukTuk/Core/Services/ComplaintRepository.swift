import FirebaseAuth
import FirebaseFirestore
import Foundation

struct ComplaintDraft {
    let userId: String
    let userRole: String
    let userName: String
    let subject: String
    let body: String
    var category: String = ""
    var targetUserId: String = ""
    var targetRole: String = ""
    var targetName: String = ""
    var relatedRideId: String = ""
}

final class ComplaintRepository {
    private let firestore = Firestore.firestore()
    private let auth = Auth.auth()

    func createComplaint(_ draft: ComplaintDraft) async throws -> String {
        let subject = draft.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty, !body.isEmpty else {
            throw NSError(
                domain: "ComplaintRepository",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Subject and body required."]
            )
        }

        var data: [String: Any] = [
            "userId": draft.userId,
            "userRole": draft.userRole,
            "userName": draft.userName,
            "subject": subject,
            "body": body,
            "status": "open",
            "adminReply": "",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if let uid = auth.currentUser?.uid {
            data["createdBy"] = uid
        }
        if !draft.category.isEmpty { data["category"] = draft.category }
        if !draft.targetUserId.isEmpty { data["targetUserId"] = draft.targetUserId }
        if !draft.targetRole.isEmpty { data["targetRole"] = draft.targetRole }
        if !draft.targetName.isEmpty { data["targetName"] = draft.targetName }
        if !draft.relatedRideId.isEmpty { data["relatedRideId"] = draft.relatedRideId }

        let ref = firestore.collection("complaints").document()
        try await ref.setData(data)
        return ref.documentID
    }
}
