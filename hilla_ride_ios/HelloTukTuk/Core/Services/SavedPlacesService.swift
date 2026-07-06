import FirebaseFirestore
import Foundation

final class SavedPlacesService {
    private let firestore = Firestore.firestore()

    func watchSavedPlaces(uid: String) -> AsyncStream<[SavedPlace]> {
        AsyncStream { continuation in
            let listener = firestore.collection("users").document(uid)
                .collection("saved_places")
                .addSnapshotListener { snapshot, _ in
                    let places = snapshot?.documents.compactMap { doc in
                        SavedPlace(documentID: doc.documentID, data: doc.data())
                    } ?? []
                    let sorted = places.sorted {
                        ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                    }
                    continuation.yield(sorted)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func addSavedPlace(uid: String, label: String, latitude: Double, longitude: Double) async throws -> SavedPlace {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SavedPlacesError.labelRequired }

        let collection = firestore.collection("users").document(uid).collection("saved_places")
        let existing = try await collection
            .whereField("latitude", isEqualTo: latitude)
            .whereField("longitude", isEqualTo: longitude)
            .limit(to: 1)
            .getDocuments()
        if let doc = existing.documents.first,
           let place = SavedPlace(documentID: doc.documentID, data: doc.data()) {
            return place
        }

        let ref = collection.document()
        try await ref.setData([
            "label": trimmed,
            "latitude": latitude,
            "longitude": longitude,
            "createdAt": FieldValue.serverTimestamp()
        ])
        let snapshot = try await ref.getDocument()
        return SavedPlace(documentID: ref.documentID, data: snapshot.data() ?? [:])!
    }

    func deleteSavedPlace(uid: String, placeId: String) async throws {
        try await firestore.collection("users").document(uid)
            .collection("saved_places").document(placeId).delete()
    }
}

enum SavedPlacesError: LocalizedError {
    case labelRequired

    var errorDescription: String? {
        switch self {
        case .labelRequired: return "Label is required."
        }
    }
}
