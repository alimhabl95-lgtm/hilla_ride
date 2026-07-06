import CoreLocation
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

    func findDriversForRide(
        districtId: String,
        subDistrictId: String,
        pickup: CLLocationCoordinate2D
    ) async throws -> [DriverProfile] {
        let snapshot = try await firestore.collection("drivers")
            .whereField("approvalStatus", isEqualTo: DriverApprovalStatus.approved.rawValue)
            .whereField("isOnline", isEqualTo: true)
            .whereField("assignedDistrictId", isEqualTo: districtId)
            .whereField("assignedSubDistrictId", isEqualTo: subDistrictId)
            .limit(to: 20)
            .getDocuments()

        let drivers = snapshot.documents.compactMap { doc in
            DriverProfile(documentID: doc.documentID, data: doc.data())
        }.filter { driver in
            driver.isApproved &&
            !driver.isBlocked &&
            !driver.hasActiveRide
        }

        return drivers.sorted { lhs, rhs in
            let lhsDistance = lhs.sortCoordinate.map {
                GeoMath.distanceKm(from: pickup, to: $0)
            } ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.sortCoordinate.map {
                GeoMath.distanceKm(from: pickup, to: $0)
            } ?? .greatestFiniteMagnitude
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.completedRidesCount < rhs.completedRidesCount
        }
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