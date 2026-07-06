import FirebaseAuth
import FirebaseFunctions
import FirebaseStorage
import Foundation

enum StorageServiceError: LocalizedError {
    case unauthorized
    case emptyFile
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Sign in again to upload photos."
        case .emptyFile: return "Photo file is empty."
        case .uploadFailed: return "Could not upload photo. Try again."
        }
    }
}

final class StorageService {
    private let storage = Storage.storage()
    private let auth = Auth.auth()
    private let functions = Functions.functions(region: "us-central1")
    private let maxPhotoBytes = 15 * 1024 * 1024

    func uploadDriverDocument(uid: String, data: Data, fileName: String) async throws -> String {
        guard let currentUID = auth.currentUser?.uid, currentUID == uid else {
            throw StorageServiceError.unauthorized
        }
        guard !data.isEmpty else {
            throw StorageServiceError.emptyFile
        }
        guard data.count <= maxPhotoBytes else {
            throw StorageServiceError.uploadFailed
        }

        _ = try? await auth.currentUser?.getIDToken(forcingRefresh: true)

        let ref = storage.reference().child("driver_applications/\(uid)/\(fileName)")
        do {
            _ = try await ref.putDataAsync(data, metadata: StorageMetadata(dictionary: ["contentType": "image/jpeg"]))
            return try await ref.downloadURL().absoluteString
        } catch let error as NSError {
            if error.domain == StorageErrorDomain,
               [StorageErrorCode.unauthorized.rawValue, StorageErrorCode.unauthenticated.rawValue].contains(error.code) {
                return try await uploadDriverDocumentViaFunction(data: data, fileName: fileName)
            }
            throw error
        }
    }

    private func uploadDriverDocumentViaFunction(data: Data, fileName: String) async throws -> String {
        let result = try await functions.httpsCallable("uploadDriverApplicationPhoto").call([
            "fileName": fileName,
            "base64": data.base64EncodedString()
        ])
        guard let payload = result.data as? [String: Any],
              let url = payload["url"] as? String,
              !url.isEmpty else {
            throw StorageServiceError.uploadFailed
        }
        return url
    }
}
