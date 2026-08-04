import CoreLocation
import FirebaseFirestore
import FirebaseFunctions
import Foundation

enum DriverServiceError: LocalizedError {
    case blocked
    case notApproved
    case workAreaRequired
    case walletBlocked

    var errorDescription: String? {
        switch self {
        case .blocked: return L10n.string(.driverBlockedTitle)
        case .notApproved: return L10n.string(.driverRejectedTitle)
        case .workAreaRequired: return L10n.string(.driverWorkAreaRequired)
        case .walletBlocked:
            return L10n.string(.walletBlockedMessage)
        }
    }
}

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

        let walletConfig = (try? await WalletService().fetchConfig()) ?? .default

        let drivers = snapshot.documents.compactMap { doc in
            DriverProfile(documentID: doc.documentID, data: doc.data())
        }.filter { driver in
            driver.isApproved &&
            !driver.isBlocked &&
            !driver.hasActiveRide &&
            driver.walletAllowsMatching(minBalanceIqd: walletConfig.minBalanceIqd)
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

    func watchDriver(uid: String) -> AsyncStream<DriverProfile?> {
        AsyncStream { continuation in
            let listener = firestore.collection("drivers").document(uid)
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot, let data = snapshot.data() else {
                        continuation.yield(nil)
                        return
                    }
                    continuation.yield(DriverProfile(documentID: snapshot.documentID, data: data))
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func setOnlineStatus(driverId: String, isOnline: Bool) async throws {
        if isOnline {
            let doc = try await firestore.collection("drivers").document(driverId).getDocument()
            guard let data = doc.data() else { return }
            if data["isBlocked"] as? Bool == true { throw DriverServiceError.blocked }
            if data["approvalStatus"] as? String != DriverApprovalStatus.approved.rawValue {
                throw DriverServiceError.notApproved
            }
            let districtId = data["assignedDistrictId"] as? String ?? ""
            let subDistrictId = data["assignedSubDistrictId"] as? String ?? ""
            if districtId.isEmpty || subDistrictId.isEmpty {
                throw DriverServiceError.workAreaRequired
            }

            let walletStatus = data["walletStatus"] as? String ?? "active"
            let walletBalance = (data["walletBalanceIqd"] as? NSNumber)?.intValue ?? 0
            let walletConfig = (try? await WalletService().fetchConfig()) ?? .default
            let minBalance = max(walletConfig.minBalanceIqd, 1)
            if walletStatus == "blocked" || walletBalance <= 0 || walletBalance < minBalance {
                throw DriverServiceError.walletBlocked
            }

            let sub = BabilRegions.subDistrict(byId: subDistrictId)
            var updates: [String: Any] = [
                "isOnline": true,
                "hasActiveRide": false,
                "operationalStatus": DriverOperationalStatus.available.rawValue,
                "onlineSince": FieldValue.serverTimestamp(),
                "locationUpdatedAt": FieldValue.serverTimestamp()
            ]
            if data["latitude"] == nil { updates["latitude"] = sub.center.latitude }
            if data["longitude"] == nil { updates["longitude"] = sub.center.longitude }
            if (data["geohash"] as? String ?? "").isEmpty {
                updates["geohash"] = Geohash.encode(
                    latitude: sub.center.latitude,
                    longitude: sub.center.longitude
                )
            }

            try await firestore.collection("drivers").document(driverId).updateData(updates)
            await DriverLocationPublisher.shared.start(for: driverId)
        } else {
            try await firestore.collection("drivers").document(driverId).updateData([
                "isOnline": false,
                "operationalStatus": DriverOperationalStatus.offline.rawValue,
                "onlineSince": NSNull()
            ])
            await DriverLocationPublisher.shared.stop()
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