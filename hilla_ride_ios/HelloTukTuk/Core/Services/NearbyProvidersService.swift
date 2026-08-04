import CoreLocation
import FirebaseFirestore
import Foundation

/// Watches nearby available drivers for the customer map.
final class NearbyProvidersService {
    private let firestore = Firestore.firestore()

    func watchNearbyAvailable(
        center: CLLocationCoordinate2D,
        radiusKm: Double = MapPresenceConfig.nearbyRadiusKm,
        maxMarkers: Int = MapPresenceConfig.maxNearbyMarkers
    ) -> AsyncStream<[MapPresence]> {
        AsyncStream { continuation in
            let session = NearbyWatchSession(
                firestore: firestore,
                center: center,
                radiusKm: radiusKm,
                maxMarkers: maxMarkers,
                continuation: continuation
            )
            session.start()
            continuation.onTermination = { _ in
                session.stop()
            }
        }
    }

    static func distanceKm(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let b = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return a.distance(from: b) / 1000
    }

    static func estimateMinutes(distanceKm: Double, speedKmh: Double = 22) -> Int {
        max(1, Int((distanceKm / speedKmh * 60).rounded()))
    }
}

/// Isolates mutable listener state so AsyncStream termination is concurrency-safe.
private final class NearbyWatchSession: @unchecked Sendable {
    private let firestore: Firestore
    private let center: CLLocationCoordinate2D
    private let radiusKm: Double
    private let maxMarkers: Int
    private let continuation: AsyncStream<[MapPresence]>.Continuation
    private var latestByPrefix: [String: [MapPresence]] = [:]
    private var listeners: [ListenerRegistration] = []
    private let lock = NSLock()

    init(
        firestore: Firestore,
        center: CLLocationCoordinate2D,
        radiusKm: Double,
        maxMarkers: Int,
        continuation: AsyncStream<[MapPresence]>.Continuation
    ) {
        self.firestore = firestore
        self.center = center
        self.radiusKm = radiusKm
        self.maxMarkers = maxMarkers
        self.continuation = continuation
    }

    func start() {
        let prefixes = Geohash.searchPrefixes(
            latitude: center.latitude,
            longitude: center.longitude
        )
        for prefix in prefixes {
            let query = firestore.collection(MapPresenceConfig.collection)
                .whereField("serviceType", isEqualTo: MapPresenceConfig.serviceTypeRide)
                .whereField("status", isEqualTo: DriverOperationalStatus.available.rawValue)
                .whereField("geohash", isGreaterThanOrEqualTo: prefix)
                .whereField("geohash", isLessThanOrEqualTo: Geohash.upperBound(prefix))
                .limit(to: 24)

            let listener = query.addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                let items = snapshot?.documents.compactMap {
                    MapPresence(documentID: $0.documentID, data: $0.data())
                } ?? []
                self.lock.lock()
                self.latestByPrefix[prefix] = items
                let merged = self.mergedProvidersLocked()
                self.lock.unlock()
                self.continuation.yield(merged)
            }
            lock.lock()
            listeners.append(listener)
            lock.unlock()
        }
    }

    func stop() {
        lock.lock()
        let active = listeners
        listeners.removeAll()
        latestByPrefix.removeAll()
        lock.unlock()
        active.forEach { $0.remove() }
    }

    private func mergedProvidersLocked() -> [MapPresence] {
        var seen = Set<String>()
        var merged: [MapPresence] = []
        for list in latestByPrefix.values {
            for item in list {
                guard seen.insert(item.providerId).inserted else { continue }
                guard item.isVisibleOnCustomerMap else { continue }
                let km = NearbyProvidersService.distanceKm(from: center, to: item.coordinate)
                guard km <= radiusKm else { continue }
                merged.append(item)
            }
        }
        merged.sort {
            NearbyProvidersService.distanceKm(from: center, to: $0.coordinate)
                < NearbyProvidersService.distanceKm(from: center, to: $1.coordinate)
        }
        return Array(merged.prefix(maxMarkers))
    }
}
