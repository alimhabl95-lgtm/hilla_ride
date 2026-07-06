import CoreLocation
import FirebaseFirestore
import Foundation

@MainActor
final class DriverLocationPublisher: NSObject, CLLocationManagerDelegate {
    static let shared = DriverLocationPublisher()

    private let manager = CLLocationManager()
    private let firestore = Firestore.firestore()
    private var activeDriverId: String?
    private var lastWriteAt: Date?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 25
        manager.allowsBackgroundLocationUpdates = false
    }

    func start(for driverId: String) {
        activeDriverId = driverId
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        activeDriverId = nil
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            await publish(location: location)
        }
    }

    private func publish(location: CLLocation) async {
        guard let driverId = activeDriverId else { return }
        if let lastWriteAt, Date().timeIntervalSince(lastWriteAt) < 8 { return }

        lastWriteAt = Date()
        try? await firestore.collection("drivers").document(driverId).updateData([
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "locationUpdatedAt": FieldValue.serverTimestamp()
        ])
    }
}
