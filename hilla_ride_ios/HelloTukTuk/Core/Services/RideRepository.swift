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
        distanceKm: Double,
        originalFareIqd: Int = 0,
        promoDiscountIqd: Int = 0,
        promoCode: String = ""
    ) async throws -> Ride {
        guard RideLocationRules.areDistinct(pickup.coordinate, destination.coordinate) else {
            throw RideServiceError.pickupDestinationSame
        }

        let active = try await fetchActiveRide(customerId: customerId)
        if active != nil {
            throw RideServiceError.activeRideExists
        }

        if await ServiceAreaCatalog.shared.validateForNewRide(
            districtId: districtId,
            subDistrictId: subDistrictId,
            pickup: pickup.coordinate
        ) != nil {
            throw RideServiceError.outOfService
        }

        let rideId = UUID().uuidString
        let rideRef = firestore.collection("rides").document(rideId)
        let rideNumber = try await allocateRideNumber()
        var payload: [String: Any] = [
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
            "rideNumber": rideNumber,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if originalFareIqd > 0 {
            payload["originalFareIqd"] = originalFareIqd
        }
        if promoDiscountIqd > 0 {
            payload["promoDiscountIqd"] = promoDiscountIqd
        }
        if !promoCode.isEmpty {
            payload["promoCode"] = promoCode
        }

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
        if districtId.isEmpty || subDistrictId.isEmpty {
            let fallback = await MainActor.run { () -> (String, String) in
                let district = BabilRegions.customerDistrict
                return (
                    district.id,
                    district.subDistricts.first?.id ?? "hashimiya_center"
                )
            }
            if districtId.isEmpty { districtId = fallback.0 }
            if subDistrictId.isEmpty { subDistrictId = fallback.1 }
        }

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
        let snapshot = try await firestore.collection("rides").document(rideId).getDocument()
        let driverId = snapshot.data()?["driverId"] as? String

        try await firestore.collection("rides").document(rideId).updateData([
            "status": RideStatus.cancelled.rawValue,
            "cancelledAt": FieldValue.serverTimestamp(),
            "cancelledBy": cancelledBy
        ])

        if let driverId, !driverId.isEmpty {
            try? await setDriverActiveRide(driverId: driverId, active: false)
        }
    }

    func acceptRide(rideId: String, driverId: String) async throws {
        let rideRef = firestore.collection("rides").document(rideId)
        let driverRef = firestore.collection("drivers").document(driverId)
        let walletConfig = (try? await WalletService().fetchConfig()) ?? .default

        try await firestore.runTransaction { transaction, errorPointer in
            let driverSnap: DocumentSnapshot
            let rideSnap: DocumentSnapshot
            do {
                driverSnap = try transaction.getDocument(driverRef)
                rideSnap = try transaction.getDocument(rideRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let driverData = driverSnap.data(), driverData["hasActiveRide"] as? Bool != true else {
                errorPointer?.pointee = NSError(domain: "RideRepository", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "driver_busy"
                ])
                return nil
            }

            let walletStatus = driverData["walletStatus"] as? String ?? "active"
            let walletBalance = (driverData["walletBalanceIqd"] as? NSNumber)?.intValue ?? 0
            let minBalance = max(walletConfig.minBalanceIqd, 1)
            if walletStatus == "blocked" || walletBalance <= 0 || walletBalance < minBalance {
                errorPointer?.pointee = NSError(domain: "RideRepository", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: L10n.string(.walletBlockedMessage)
                ])
                return nil
            }

            guard let data = rideSnap.data() else {
                errorPointer?.pointee = NSError(domain: "RideRepository", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "ride_not_found"
                ])
                return nil
            }

            let estimatedCommission = (data["platformCommissionIqd"] as? NSNumber)?.intValue ?? 0
            if estimatedCommission > 0 && walletBalance < estimatedCommission {
                errorPointer?.pointee = NSError(domain: "RideRepository", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: L10n.string(.walletBlockedMessage)
                ])
                return nil
            }

            let status = RideStatus.fromFirestore(data["status"] as? String)
            guard status == .matched || status == .searching else {
                errorPointer?.pointee = NSError(domain: "RideRepository", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "ride_unavailable"
                ])
                return nil
            }

            if let assigned = data["driverId"] as? String, !assigned.isEmpty, assigned != driverId {
                errorPointer?.pointee = NSError(domain: "RideRepository", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "ride_taken"
                ])
                return nil
            }

            transaction.updateData([
                "driverId": driverId,
                "status": RideStatus.accepted.rawValue,
                "acceptedAt": FieldValue.serverTimestamp(),
                "offeredDriverIds": [],
                "notifyDrivers": false,
                "notifyCustomer": true
            ], forDocument: rideRef)
            transaction.updateData([
                "hasActiveRide": true,
                "operationalStatus": DriverOperationalStatus.arrivingPickup.rawValue
            ], forDocument: driverRef)
            return nil
        }
    }

    func rejectRide(rideId: String, driverId: String) async throws {
        let rideRef = firestore.collection("rides").document(rideId)
        let snapshot = try await rideRef.getDocument()
        guard var data = snapshot.data() else { throw RideServiceError.rideNotFound }

        let status = RideStatus.fromFirestore(data["status"] as? String)
        guard status == .matched else { throw RideServiceError.rideUnavailable }
        if data["driverId"] != nil { throw RideServiceError.rideUnavailable }

        var offered = (data["offeredDriverIds"] as? [String]) ?? []
        guard offered.contains(driverId) else { throw RideServiceError.rideUnavailable }

        var rejected = (data["rejectedDriverIds"] as? [String]) ?? []
        rejected.append(driverId)
        offered.removeAll { $0 == driverId }

        if offered.isEmpty {
            try await rideRef.updateData([
                "offeredDriverIds": [],
                "rejectedDriverIds": rejected,
                "status": RideStatus.searching.rawValue,
                "notifyDrivers": false
            ])
            try? await assignNearestDriver(rideId: rideId)
        } else {
            try await rideRef.updateData([
                "offeredDriverIds": offered,
                "rejectedDriverIds": rejected
            ])
        }
    }

    func startRide(rideId: String) async throws {
        let rideDoc = try await firestore.collection("rides").document(rideId).getDocument()
        let driverId = rideDoc.data()?["driverId"] as? String
        try await firestore.collection("rides").document(rideId).updateData([
            "status": RideStatus.inProgress.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ])
        if let driverId, !driverId.isEmpty {
            try await firestore.collection("drivers").document(driverId).updateData([
                "operationalStatus": DriverOperationalStatus.onTrip.rawValue
            ])
        }
    }

    func endRideAwaitingCash(rideId: String) async throws {
        try await firestore.collection("rides").document(rideId).updateData([
            "status": RideStatus.awaitingCashPayment.rawValue,
            "endedAt": FieldValue.serverTimestamp()
        ])
    }

    func confirmCashCollected(rideId: String) async throws {
        let rideRef = firestore.collection("rides").document(rideId)
        let commissionService = CommissionService()
        let platformPercent = await commissionService.getConfig()

        _ = try await firestore.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(rideRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            guard let data = snapshot.data() else { return nil }
            if data["earningsApplied"] as? Bool == true { return nil }

            let status = RideStatus.fromFirestore(data["status"] as? String)
            guard status == .awaitingCashPayment || status == .completed else { return nil }

            let fare = (data["fareAmountIqd"] as? NSNumber)?.intValue ?? 0
            let split = commissionService.splitFare(fareIqd: fare, platformPercent: platformPercent)

            transaction.updateData([
                "cashCollectedByDriver": true,
                "status": RideStatus.completed.rawValue,
                "completedAt": FieldValue.serverTimestamp(),
                "commissionPercent": split.commissionPercent,
                "platformCommissionIqd": split.platformCommissionIqd,
                "driverEarningsIqd": split.driverEarningsIqd,
                "earningsApplied": true
            ], forDocument: rideRef)

            if let driverId = data["driverId"] as? String, !driverId.isEmpty {
                let driverRef = self.firestore.collection("drivers").document(driverId)
                transaction.updateData([
                    "totalFareCollectedIqd": FieldValue.increment(Int64(fare)),
                    "totalPlatformCommissionIqd": FieldValue.increment(Int64(split.platformCommissionIqd)),
                    "outstandingPlatformCommissionIqd": FieldValue.increment(Int64(split.platformCommissionIqd)),
                    "totalDriverEarningsIqd": FieldValue.increment(Int64(split.driverEarningsIqd)),
                    "outstandingDriverEarningsIqd": FieldValue.increment(Int64(split.driverEarningsIqd)),
                      "completedRidesCount": FieldValue.increment(Int64(1)),
                    "hasActiveRide": false,
                    "operationalStatus": DriverOperationalStatus.available.rawValue
                ], forDocument: driverRef)
            }

            let customerId = data["customerId"] as? String
            let promoCode = data["promoCode"] as? String ?? ""
            let promoDiscount = (data["promoDiscountIqd"] as? NSNumber)?.intValue ?? 0
            if let customerId, !customerId.isEmpty, !promoCode.isEmpty, promoDiscount > 0 {
                let userRef = self.firestore.collection("users").document(customerId)
                transaction.updateData([
                    "promoRidesUsed": FieldValue.increment(Int64(1))
                ], forDocument: userRef)
            }
            return nil
        }

        if let driverId = (try? await rideRef.getDocument())?.data()?["driverId"] as? String {
            await MonthlyPrizeService().incrementDriverMonthlyRide(driverId: driverId)
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

        let rideRef = firestore.collection("rides").document(rideId)
        let snapshot = try await rideRef.getDocument()
        guard let data = snapshot.data(),
              data["customerId"] as? String == customerId,
              data["status"] as? String == RideStatus.completed.rawValue,
              data["driverRating"] == nil else { return }

        try await rideRef.updateData([
            "driverRating": rating,
            "driverFeedback": feedback.trimmingCharacters(in: .whitespacesAndNewlines),
            "ratedAt": FieldValue.serverTimestamp()
        ])

        if let driverId = data["driverId"] as? String, !driverId.isEmpty {
            let driverRef = firestore.collection("drivers").document(driverId)
            let driverSnap = try await driverRef.getDocument()
            let driverData = driverSnap.data() ?? [:]
            let oldCount = (driverData["ratingCount"] as? NSNumber)?.intValue ?? 0
            let oldRating = (driverData["rating"] as? NSNumber)?.doubleValue ?? 5.0
            let newCount = oldCount + 1
            let newRating = ((oldRating * Double(oldCount)) + Double(rating)) / Double(newCount)
            try await driverRef.updateData([
                "rating": newRating,
                "ratingCount": newCount
            ])
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
        let driverDoc = try await firestore.collection("drivers").document(driverId).getDocument()
        let isOnline = driverDoc.data()?["isOnline"] as? Bool ?? false
        try await firestore.collection("drivers").document(driverId).updateData([
            "hasActiveRide": active,
            "operationalStatus": active
                ? DriverOperationalStatus.arrivingPickup.rawValue
                : (isOnline
                    ? DriverOperationalStatus.available.rawValue
                    : DriverOperationalStatus.offline.rawValue)
        ])
    }

    private func allocateRideNumber() async throws -> String {
        let ref = firestore.collection("config").document("ride_counter")
        let result = try await firestore.runTransaction { transaction, errorPointer -> Any? in
            do {
                let snapshot = try transaction.getDocument(ref)
                let next = (snapshot.data()?["nextNumber"] as? NSNumber)?.intValue ?? 100_001
                transaction.setData(
                    [
                        "nextNumber": next + 1,
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: ref,
                    merge: true
                )
                return next
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        if let number = result as? Int {
            return String(number)
        }
        if let number = (result as? NSNumber)?.intValue {
            return String(number)
        }
        return "100001"
    }
}
