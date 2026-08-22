import CoreLocation
import FirebaseFirestore
import Foundation

/// Publishes the customer's GPS to `users/{uid}` while they have an active ride
/// so the driver can see them live on the map.
@MainActor
final class CustomerLocationPublisher: NSObject, CLLocationManagerDelegate {
    static let shared = CustomerLocationPublisher()

    private let manager = CLLocationManager()
    private let firestore = Firestore.firestore()
    private var activeUserId: String?
    private var lastWriteAt: Date?
    private var lastWritten: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = MapPresenceConfig.locationPublishMinMoveMeters
        manager.allowsBackgroundLocationUpdates = false
    }

    func start(for userId: String) {
        activeUserId = userId
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        activeUserId = nil
        manager.stopUpdatingLocation()
        lastWriteAt = nil
        lastWritten = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await publish(location: location)
        }
    }

    private func publish(location: CLLocation) async {
        guard let userId = activeUserId else { return }
        if let lastWriteAt,
           Date().timeIntervalSince(lastWriteAt) < MapPresenceConfig.locationPublishMinInterval,
           let lastWritten,
           location.distance(from: lastWritten) < MapPresenceConfig.locationPublishMinMoveMeters {
            return
        }

        lastWriteAt = Date()
        lastWritten = location
        try? await firestore.collection("users").document(userId).setData([
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "locationUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}
