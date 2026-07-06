import FirebaseFirestore
import Foundation

final class SessionService {
    private let firestore = Firestore.firestore()
    private let defaults = UserDefaults.standard

    private func prefsKey(for uid: String) -> String {
        "active_session_\(uid)"
    }

    private func readLocalSession(uid: String) -> String? {
        defaults.string(forKey: prefsKey(for: uid))
    }

    private func writeLocalSession(uid: String, sessionID: String) {
        defaults.set(sessionID, forKey: prefsKey(for: uid))
    }

    private func clearLocalSession(uid: String) {
        defaults.removeObject(forKey: prefsKey(for: uid))
    }

    private func readRemoteSession(uid: String) async throws -> String? {
        let doc = try await firestore.collection("users").document(uid).getDocument()
        guard let value = doc.data()?["activeSessionId"] as? String, !value.isEmpty else {
            return nil
        }
        return value
    }

    func claimSession(uid: String) async throws {
        let sessionID = UUID().uuidString
        writeLocalSession(uid: uid, sessionID: sessionID)
        try await firestore.collection("users").document(uid).setData([
            "activeSessionId": sessionID,
            "activeSessionUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func clearSession(uid: String) async {
        if let local = readLocalSession(uid: uid),
           let remote = try? await readRemoteSession(uid: uid),
           local == remote {
            try? await firestore.collection("users").document(uid).updateData([
                "activeSessionId": FieldValue.delete(),
                "activeSessionUpdatedAt": FieldValue.serverTimestamp()
            ])
        }
        clearLocalSession(uid: uid)
    }

    func validateLocalSession(uid: String) async throws -> Bool {
        let remote = try await readRemoteSession(uid: uid)
        if remote == nil {
            try await claimSession(uid: uid)
            return true
        }
        guard let local = readLocalSession(uid: uid), local == remote else {
            return false
        }
        return true
    }

    func isSessionValid(uid: String) async -> Bool {
        guard let remote = try? await readRemoteSession(uid: uid) else { return true }
        guard let local = readLocalSession(uid: uid) else { return false }
        return local == remote
    }

    func watchRemoteSession(uid: String) -> AsyncStream<String?> {
        AsyncStream { continuation in
            let listener = firestore.collection("users").document(uid)
                .addSnapshotListener { snapshot, _ in
                    let value = snapshot?.data()?["activeSessionId"] as? String
                    continuation.yield(value?.isEmpty == false ? value : nil)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
