import AudioToolbox
import FirebaseFirestore
import Foundation

enum RideAlertType: Equatable {
    case driverRideRequest
    case customerRideAccepted
    case chatMessage
}

struct RideAlertEvent: Identifiable, Equatable {
    let id = UUID()
    let type: RideAlertType
    let title: String
    let body: String
}

@MainActor
final class RideAlertService: ObservableObject {
    static let shared = RideAlertService()

    @Published private(set) var activeAlert: RideAlertEvent?

    private let firestore = Firestore.firestore()
    private var driverOfferTask: Task<Void, Never>?
    private var customerRideTask: Task<Void, Never>?
    private var chatTask: Task<Void, Never>?
    private var announcementTask: Task<Void, Never>?

    private var notifiedDriverRideIds = Set<String>()
    private var notifiedCustomerAcceptedRideIds = Set<String>()
    private var lastCustomerRideStatus: RideStatus?
    private var messagesReadyByRide = [String: Bool]()
    private var announcementListenerReady = false
    private var foregroundChatRideId: String?

    private init() {}

    func setForegroundChatRideId(_ rideId: String?) {
        foregroundChatRideId = rideId
    }

    func startListeners(uid: String, role: UserRole) {
        stopListeners()
        lastCustomerRideStatus = nil
        notifiedDriverRideIds.removeAll()
        notifiedCustomerAcceptedRideIds.removeAll()
        messagesReadyByRide.removeAll()
        announcementListenerReady = false

        switch role {
        case .driver:
            startDriverOfferListener(driverId: uid)
            startChatListener(uid: uid, role: role)
            startAnnouncementListener(audience: "drivers")
        case .customer:
            startCustomerRideListener(customerId: uid)
            startChatListener(uid: uid, role: role)
            startAnnouncementListener(audience: "customers")
        default:
            break
        }
    }

    func stopListeners() {
        driverOfferTask?.cancel()
        customerRideTask?.cancel()
        chatTask?.cancel()
        announcementTask?.cancel()
        driverOfferTask = nil
        customerRideTask = nil
        chatTask = nil
        announcementTask = nil
        dismissAlert()
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "ar") ?? .arabic
    }

    func trigger(_ event: RideAlertEvent) {
        activeAlert = event
        AudioServicesPlaySystemSound(1007)
    }

    func dismissAlert() {
        activeAlert = nil
    }

    private func startDriverOfferListener(driverId: String) {
        driverOfferTask = Task {
            let stream = AsyncStream<[Ride]> { continuation in
                let listener = firestore.collection("rides")
                    .whereField("offeredDriverIds", arrayContains: driverId)
                    .whereField("status", isEqualTo: RideStatus.matched.rawValue)
                    .limit(to: 5)
                    .addSnapshotListener { snapshot, _ in
                        let rides = snapshot?.documents.compactMap { doc in
                            Ride(documentID: doc.documentID, data: doc.data())
                        } ?? []
                        continuation.yield(rides)
                    }
                continuation.onTermination = { _ in listener.remove() }
            }

            for await rides in stream {
                guard !Task.isCancelled else { break }
                var activeOfferIds = Set<String>()
                var hasNewOffer = false
                for ride in rides where ride.driverId == nil {
                    activeOfferIds.insert(ride.id)
                    if !notifiedDriverRideIds.contains(ride.id) {
                        hasNewOffer = true
                    }
                    notifyDriverRideIfNew(ride)
                }
                let stale = notifiedDriverRideIds.filter { !activeOfferIds.contains($0) }
                if !stale.isEmpty && !hasNewOffer {
                    stale.forEach { notifiedDriverRideIds.remove($0) }
                }
            }
        }
    }

    private func startCustomerRideListener(customerId: String) {
        customerRideTask = Task {
            let stream = RideRepository().watchActiveRide(customerId: customerId)
            for await ride in stream {
                guard !Task.isCancelled else { break }
                guard let ride else {
                    lastCustomerRideStatus = nil
                    continue
                }
                let previous = lastCustomerRideStatus
                lastCustomerRideStatus = ride.status
                let acceptedNow = ride.status == .accepted
                    && !notifiedCustomerAcceptedRideIds.contains(ride.id)
                    && (previous != .accepted || previous == nil)
                if acceptedNow {
                    notifiedCustomerAcceptedRideIds.insert(ride.id)
                    trigger(RideAlertEvent(
                        type: .customerRideAccepted,
                        title: L10n.string(.driverAcceptedAlertTitle, language: appLanguage),
                        body: L10n.string(.driverAcceptedAlertBody, language: appLanguage)
                    ))
                }
            }
        }
    }

    private func startChatListener(uid: String, role: UserRole) {
        chatTask = Task {
            let rideStream: AsyncStream<Ride?>
            if role == .driver {
                rideStream = RideRepository().watchAssignedRide(for: uid)
            } else {
                rideStream = RideRepository().watchActiveRide(customerId: uid)
            }

            var activeRideId: String?
            var messageTask: Task<Void, Never>?

            for await ride in rideStream {
                guard !Task.isCancelled else { break }
                let nextRideId = ride?.id
                if nextRideId == activeRideId { continue }
                activeRideId = nextRideId
                messageTask?.cancel()
                messageTask = nil
                guard let nextRideId else { continue }
                messagesReadyByRide[nextRideId] = false

                messageTask = Task {
                    for await messages in ChatService().watchRideMessages(rideId: nextRideId) {
                        guard !Task.isCancelled else { break }
                        handleChatMessages(
                            messages: messages,
                            uid: uid,
                            role: role,
                            rideId: nextRideId
                        )
                    }
                }
            }
        }
    }

    private func handleChatMessages(
        messages: [RideMessage],
        uid: String,
        role: UserRole,
        rideId: String
    ) {
        if messagesReadyByRide[rideId] != true {
            messagesReadyByRide[rideId] = true
            return
        }
        if foregroundChatRideId == rideId { return }
        guard let last = messages.last else { return }
        guard last.senderId != uid, last.senderRole != role else { return }

        let preview: String
        if last.isVoice {
            preview = "\(last.senderName): \(L10n.string(.voiceMessagePreview, language: appLanguage))"
        } else {
            preview = last.text.isEmpty ? last.senderName : "\(last.senderName): \(last.text)"
        }
        let title = role == .customer
            ? L10n.string(.chatWithDriver, language: appLanguage)
            : L10n.string(.chatWithCustomer, language: appLanguage)
        trigger(RideAlertEvent(type: .chatMessage, title: title, body: preview))
    }

    private func startAnnouncementListener(audience: String) {
        announcementTask = Task {
            let stream = AsyncStream<[Announcement]> { continuation in
                let listener = firestore.collection("announcements")
                    .whereField("audience", isEqualTo: audience)
                    .limit(to: 12)
                    .addSnapshotListener { snapshot, _ in
                        let items = snapshot?.documentChanges.compactMap { change -> Announcement? in
                            guard change.type == .added else { return nil }
                            return Announcement(documentID: change.document.documentID, data: change.document.data())
                        } ?? []
                        continuation.yield(items)
                    }
                continuation.onTermination = { _ in listener.remove() }
            }

            for await added in stream {
                guard !Task.isCancelled else { break }
                if !announcementListenerReady {
                    announcementListenerReady = true
                    continue
                }
                for item in added {
                    trigger(RideAlertEvent(
                        type: .chatMessage,
                        title: item.title,
                        body: item.body
                    ))
                }
            }
        }
    }

    private func notifyDriverRideIfNew(_ ride: Ride) {
        guard ride.status == .matched, !notifiedDriverRideIds.contains(ride.id) else { return }
        notifiedDriverRideIds.insert(ride.id)
        trigger(RideAlertEvent(
            type: .driverRideRequest,
            title: L10n.string(.newRideOffer, language: appLanguage),
            body: "\(ride.pickupLabel) → \(ride.destinationLabel)"
        ))
    }
}
