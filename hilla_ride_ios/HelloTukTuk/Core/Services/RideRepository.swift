import CoreLocation
import FirebaseFirestore
import Foundation

enum RideServiceError: LocalizedError {
    case pickupDestinationSame
    case activeRideExists
    case outOfService
    case noDrivers
    case rideNotFound
    case rideUnavailable

    var errorDescription: String? {
        switch self {
        case .pickupDestinationSame: return L10n.string(.pickupDestinationSame)
        case .activeRideExists: return L10n.string(.activeRideExists)
        case .outOfService: return L10n.string(.outOfService)
        case .noDrivers: return L10n.string(.noDriversAvailable)
        case .rideNotFound: return "Ride not found."
        case .rideUnavailable: return "Ride is no longer available."
        }
    }
}

final class RideRepository {
    private let firestore = Firestore.firestore()
    private let driverRepository = DriverRepository()

    func watchActiveRide(customerId: String) -> AsyncStream<Ride?> {
        AsyncStream { continuation in
            let listener = firestore.collection("rides")
                .whereField("customerId", isEqualTo: customerId)
                .whereField("status", in: RideStatus.activeCustomerStatuses)
                .addSnapshotListener { snapshot, _ in
                    let rides = snapshot?.documents.compactMap { doc in
                        Ride(documentID: doc.documentID, data: doc.data())
                    } ?? []
                    let latest = rides.sorted {
                        ($0.id) > ($1.id)
                    }.first
                    continuation.yield(latest)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func watchRide(rideId: String) -> AsyncStream<Ride?> {
        AsyncStream { continuation in
            let listener = firestore.collection("rides").document(rideId)
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot, let data = snapshot.data() else {
                        continuation.yield(nil)
                        return
                    }
                    continuation.yield(Ride(documentID: snapshot.documentID, data: data))
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func bookRide(
        customerId: String,
        pickup: MapPlace,
        destination: MapPlace,
        districtId: String,
        subDistrictId: String,
        fareAmountIqd: Int,
        distanceKm: Double
    ) async throws -> Ride {
        guard RideLocationRules.areDistinct(pickup.coordinate, destination.coordinate) else {
            throw RideServiceError.pickupDestinationSame
        }

        let active = try await fetchActiveRide(customerId: customerId)
        if active != nil {
            throw RideServiceError.activeRideExists
        }

        let rideId = UUID().uuidString
        let rideRef = firestore.collection("rides").document(rideId)
        let payload: [String: Any] = [
            "customerId": customerId,
            "pickupLabel": pickup.label,
            "destinationLabel": destination.label,
            "pickupLat": pickup.latitude,
            "pickupLng": pickup.longitude,
            "destinationLat": destination.latitude,
            "destinationLng": destination.longitude,
            "status": RideStatus.searching.rawValue,
            "fareAmountIqd": fareAmountIqd,
            "paymentMethod": "cash",
            "districtId": districtId,
            "subDistrictId": subDistrictId,
            "distanceKm": distanceKm,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await rideRef.setData(payload)

        do {
            try await assignNearestDriver(rideId: rideId)
        } catch {
            // Assignment can fail when no drivers are online; the ride stays in searching.
        }

        let latest = try await rideRef.getDocument()
        guard let data = latest.data(),
              let ride = Ride(documentID: rideId, data: data) else {
            throw RideServiceError.rideNotFound
        }
        return ride
    }

    func assignNearestDriver(rideId: String) async throws {
        let rideRef = firestore.collection("rides").document(rideId)
        let snapshot = try await rideRef.getDocument()
        guard let data = snapshot.data(),
              let ride = Ride(documentID: rideId, data: data) else {
            throw RideServiceError.rideNotFound
        }

        if ride.status != .searching {
            return
        }

        var districtId = ride.districtId
        var subDistrictId = ride.subDistrictId
        if districtId.isEmpty { districtId = BabilRegions.customerDistrictId }
        if subDistrictId.isEmpty { subDistrictId = BabilRegions.customerDistrict.subDistricts[0].id }

        let drivers = try await driverRepository.findDriversForRide(
            districtId: districtId,
            subDistrictId: subDistrictId,
            pickup: ride.pickupCoordinate
        )

        guard !drivers.isEmpty else {
            throw RideServiceError.noDrivers
        }

        if let autoAccept = drivers.first(where: { $0.isFakeDriver && $0.autoAcceptRides }) {
            try await rideRef.updateData([
                "driverId": autoAccept.uid,
                "offeredDriverIds": [autoAccept.uid],
                "status": RideStatus.accepted.rawValue,
                "matchedAt": FieldValue.serverTimestamp(),
                "acceptedAt": FieldValue.serverTimestamp(),
                "notifyCustomer": true
            ])
            try await setDriverActiveRide(driverId: autoAccept.uid, active: true)
            return
        }

        let offeredDriverIds = drivers.map(\.uid)
        try await rideRef.updateData([
            "offeredDriverIds": offeredDriverIds,
            "status": RideStatus.matched.rawValue,
            "matchedAt": FieldValue.serverTimestamp(),
            "notifyDrivers": true
        ])
    }

    func cancelRide(rideId: String, cancelledBy: String) async throws {
        try await firestore.collection("rides").document(rideId).updateData([
            "status": RideStatus.cancelled.rawValue,
            "cancelledAt": FieldValue.serverTimestamp(),
            "cancelledBy": cancelledBy
        ])
    }

    private func fetchActiveRide(customerId: String) async throws -> Ride? {
        let snapshot = try await firestore.collection("rides")
            .whereField("customerId", isEqualTo: customerId)
            .whereField("status", in: RideStatus.activeCustomerStatuses)
            .limit(to: 1)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            Ride(documentID: doc.documentID, data: doc.data())
        }.first
    }

    private func setDriverActiveRide(driverId: String, active: Bool) async throws {
        try await firestore.collection("drivers").document(driverId).updateData([
            "hasActiveRide": active
        ])
    }
}
