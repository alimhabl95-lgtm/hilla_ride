import CoreLocation
import FirebaseFirestore
import FirebaseFunctions
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
    private let functions = Functions.functions(region: "us-central1")

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
        distanceKm: Double,
        originalFareIqd: Int = 0,
        promoDiscountIqd: Int = 0,
        promoCode: String = ""
    ) async throws -> Ride {
        guard RideLocationRules.areDistinct(pickup.coordinate, destination.coordinate) else {
            throw RideServiceError.pickupDestinationSame
        }

        if await ServiceAreaCatalog.shared.validateForNewRide(
            districtId: districtId,
            subDistrictId: subDistrictId,
            pickup: pickup.coordinate
        ) != nil {
            throw RideServiceError.outOfService
        }

        var payload: [String: Any] = [
            "pickupLabel": pickup.label,
            "destinationLabel": destination.label,
            "pickupLat": pickup.latitude,
            "pickupLng": pickup.longitude,
            "destinationLat": destination.latitude,
            "destinationLng": destination.longitude,
            "districtId": districtId,
            "subDistrictId": subDistrictId,
            "fareAmountIqd": fareAmountIqd,
            "distanceKm": distanceKm
        ]
        if originalFareIqd > 0 { payload["originalFareIqd"] = originalFareIqd }
        if promoDiscountIqd > 0 { payload["promoDiscountIqd"] = promoDiscountIqd }
        if !promoCode.isEmpty { payload["promoCode"] = promoCode }

        do {
            let result = try await functions.httpsCallable("createRide").call(payload)
            let data = result.data as? [String: Any] ?? [:]
            let rideId = data["rideId"] as? String ?? ""
            guard !rideId.isEmpty else { throw RideServiceError.rideNotFound }
            let latest = try await firestore.collection("rides").document(rideId).getDocument()
            guard let rideData = latest.data(),
                  let ride = Ride(documentID: rideId, data: rideData) else {
                throw RideServiceError.rideNotFound
            }
            return ride
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func assignNearestDriver(rideId: String) async throws {
        do {
            _ = try await functions.httpsCallable("assignNearestDriver").call([
                "rideId": rideId
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func cancelRide(rideId: String, cancelledBy: String) async throws {
        do {
            _ = try await functions.httpsCallable("cancelRide").call([
                "rideId": rideId,
                "cancelledBy": cancelledBy
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func acceptRide(rideId: String, driverId: String) async throws {
        do {
            _ = try await functions.httpsCallable("acceptRide").call([
                "rideId": rideId
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func rejectRide(rideId: String, driverId: String) async throws {
        do {
            _ = try await functions.httpsCallable("rejectRide").call([
                "rideId": rideId
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func startRide(rideId: String) async throws {
        do {
            _ = try await functions.httpsCallable("startRide").call([
                "rideId": rideId
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func endRideAwaitingCash(rideId: String) async throws {
        do {
            _ = try await functions.httpsCallable("endRideAwaitingCash").call([
                "rideId": rideId
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func confirmCashCollected(rideId: String) async throws {
        do {
            _ = try await functions.httpsCallable("confirmCashCollected").call([
                "rideId": rideId
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func watchRideHistoryForCustomer(customerId: String, statusFilter: RideStatus? = nil) -> AsyncStream<[Ride]> {
        watchRideHistory(queryField: "customerId", id: customerId, statusFilter: statusFilter)
    }

    func watchRideHistoryForDriver(driverId: String, statusFilter: RideStatus? = nil) -> AsyncStream<[Ride]> {
        watchRideHistory(queryField: "driverId", id: driverId, statusFilter: statusFilter)
    }

    private func watchRideHistory(
        queryField: String,
        id: String,
        statusFilter: RideStatus?
    ) -> AsyncStream<[Ride]> {
        AsyncStream { continuation in
            var query: Query = firestore.collection("rides")
                .whereField(queryField, isEqualTo: id)
            if let statusFilter {
                query = query.whereField("status", isEqualTo: statusFilter.rawValue)
            }
            let listener = query
                .order(by: "createdAt", descending: true)
                .limit(to: 40)
                .addSnapshotListener { snapshot, _ in
                    let rides = snapshot?.documents.compactMap { doc in
                        Ride(documentID: doc.documentID, data: doc.data())
                    } ?? []
                    let history: [Ride]
                    if statusFilter != nil {
                        history = rides
                    } else {
                        history = rides.filter {
                            $0.status == .completed || $0.status == .cancelled
                        }
                    }
                    continuation.yield(history)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func submitDriverRating(
        rideId: String,
        customerId: String,
        rating: Int,
        feedback: String
    ) async throws {
        guard (1...5).contains(rating) else { return }
        do {
            _ = try await functions.httpsCallable("submitDriverRating").call([
                "rideId": rideId,
                "rating": rating,
                "feedback": feedback.trimmingCharacters(in: .whitespacesAndNewlines)
            ])
        } catch {
            throw mapRideCallableError(error)
        }
    }

    func watchAssignedRide(for driverId: String) -> AsyncStream<Ride?> {
        AsyncStream { continuation in
            var assigned: Ride?
            var offered: Ride?

            func publish() {
                continuation.yield(assigned ?? offered)
            }

            let assignedListener = firestore.collection("rides")
                .whereField("driverId", isEqualTo: driverId)
                .whereField("status", in: [
                    RideStatus.accepted.rawValue,
                    RideStatus.inProgress.rawValue,
                    RideStatus.awaitingCashPayment.rawValue,
                    RideStatus.matched.rawValue
                ])
                .addSnapshotListener { snapshot, _ in
                    assigned = snapshot?.documents.compactMap {
                        Ride(documentID: $0.documentID, data: $0.data())
                    }.first
                    publish()
                }

            let offeredListener = firestore.collection("rides")
                .whereField("offeredDriverIds", arrayContains: driverId)
                .whereField("status", isEqualTo: RideStatus.matched.rawValue)
                .addSnapshotListener { snapshot, _ in
                    if assigned != nil {
                        offered = nil
                        publish()
                        return
                    }
                    offered = snapshot?.documents.compactMap {
                        Ride(documentID: $0.documentID, data: $0.data())
                    }.first
                    publish()
                }

            continuation.onTermination = { _ in
                assignedListener.remove()
                offeredListener.remove()
            }
        }
    }




    private func mapRideCallableError(_ error: Error) -> Error {
        let ns = error as NSError
        let message = (ns.localizedDescription + " " + (ns.userInfo["NSLocalizedFailureReason"] as? String ?? "")).lowercased()
        if message.contains("active_ride") || message.contains("active ride") {
            return RideServiceError.activeRideExists
        }
        if message.contains("out_of_service") || message.contains("out of service") {
            return RideServiceError.outOfService
        }
        if message.contains("no_drivers") {
            return RideServiceError.noDrivers
        }
        if message.contains("ride_not_found") {
            return RideServiceError.rideNotFound
        }
        if message.contains("ride_unavailable") || message.contains("ride_taken") || message.contains("ride_not_ready") {
            return RideServiceError.rideUnavailable
        }
        if message.contains("pickup") && message.contains("destination") {
            return RideServiceError.pickupDestinationSame
        }
        return error
    }
}
