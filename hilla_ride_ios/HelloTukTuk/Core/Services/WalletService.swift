import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation

enum WalletServiceError: LocalizedError {
    case unauthorized
    case invalidAmount
    case screenshotRequired
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Sign in required."
        case .invalidAmount: return "Minimum recharge is 1000 IQD."
        case .screenshotRequired: return "Payment screenshot is required."
        case .uploadFailed: return "Could not upload screenshot."
        }
    }
}

final class WalletService {
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    private let functions = Functions.functions(region: "us-central1")
    private let auth = Auth.auth()

    func fetchConfig() async throws -> WalletConfig {
        let doc = try await firestore.collection("config").document("wallet").getDocument()
        return WalletConfig(data: doc.data())
    }

    func watchConfig() -> AsyncStream<WalletConfig> {
        AsyncStream { continuation in
            let listener = firestore.collection("config").document("wallet")
                .addSnapshotListener { snapshot, _ in
                    continuation.yield(WalletConfig(data: snapshot?.data()))
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchLedger(driverId: String) -> AsyncStream<[WalletLedgerEntry]> {
        AsyncStream { continuation in
            let listener = firestore.collection("walletLedger")
                .whereField("driverId", isEqualTo: driverId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .addSnapshotListener { snapshot, _ in
                    let entries = snapshot?.documents.compactMap {
                        WalletLedgerEntry(documentID: $0.documentID, data: $0.data())
                    } ?? []
                    continuation.yield(entries)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func uploadRechargeScreenshot(driverId: String, data: Data) async throws -> String {
        guard let uid = auth.currentUser?.uid, uid == driverId else {
            throw WalletServiceError.unauthorized
        }
        guard !data.isEmpty else { throw WalletServiceError.uploadFailed }
        let id = UUID().uuidString
        let ref = storage.reference().child("wallet_recharges/\(driverId)/\(id).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        return try await ref.downloadURL().absoluteString
    }

    func submitRechargeRequest(
        amountIqd: Int,
        method: String,
        screenshotUrl: String,
        referenceNumber: String,
        notes: String
    ) async throws {
        guard amountIqd >= 1000 else { throw WalletServiceError.invalidAmount }
        guard !screenshotUrl.isEmpty else { throw WalletServiceError.screenshotRequired }
        _ = try await functions.httpsCallable("submitWalletRechargeRequest").call([
            "amountIqd": amountIqd,
            "method": method,
            "screenshotUrl": screenshotUrl,
            "referenceNumber": referenceNumber,
            "notes": notes
        ])
    }
}
