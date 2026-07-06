import FirebaseFirestore
import FirebaseFunctions
import Foundation

final class DriverRepository {
    private let firestore = Firestore.firestore()

    func fetchDriver(uid: String) async throws -> DriverProfile? {
        let doc = try await firestore.collection("drivers").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return DriverProfile(documentID: doc.documentID, data: data)
    }

    func submitRegistration(
        phone: String,
        name: String,
        vehicleType: String,
        vehiclePlate: String,
        vehicleColor: String,
        idPhotoURL: String,
        profilePhotoURL: String
    ) async throws {
        let functions = Functions.functions(region: "us-central1")
        _ = try await functions.httpsCallable("submitDriverRegistration").call([
            "phone": phone,
            "name": name,
            "vehicleType": vehicleType,
            "vehiclePlate": vehiclePlate,
            "vehicleColor": vehicleColor,
            "licenseNumber": "",
            "idPhotoUrl": idPhotoURL,
            "profilePhotoUrl": profilePhotoURL
        ])
    }
}