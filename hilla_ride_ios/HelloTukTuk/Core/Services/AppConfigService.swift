import FirebaseFirestore
import Foundation

final class AppConfigService {
    static let shared = AppConfigService()

    private let firestore = Firestore.firestore()
    private let docPath = "config/app"

    private init() {}

    func watchConfig() -> AsyncStream<AppRemoteConfig> {
        AsyncStream { continuation in
            let listener = firestore.document(docPath).addSnapshotListener { snapshot, _ in
                let config = AppRemoteConfig.fromMap(snapshot?.data())
                continuation.yield(config)
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func fetchConfig() async -> AppRemoteConfig {
        do {
            let snapshot = try await firestore.document(docPath).getDocument()
            return AppRemoteConfig.fromMap(snapshot.data())
        } catch {
            return .defaults
        }
    }
}
