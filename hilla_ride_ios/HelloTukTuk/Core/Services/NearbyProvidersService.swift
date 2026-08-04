import CoreLocation
import FirebaseFirestore
import Foundation

@MainActor
final class NearbyProvidersService {
    private let firestore = Firestore.firestore()

    func watchNearbyAvailable(
        center: CLLocationCoordinate2D,
        radiusKm: Double = MapPresenceConfig.nearbyRadiusKm,
        maxMarkers: Int = MapPresenceConfig.maxNearbyMarkers
    ) -> AsyncStream<[MapPresence]> {
        AsyncStream { continuation in
            let prefixes = Geohash.searchPrefixes(
                latitude: center.latitude,
                longitude: center.longitude
            )
            var latestByPrefix: [String: [MapPresence]] = [:]
            var listeners: [ListenerRegistration] = []

            func emit() {
                var seen = Set<String>()
                var merged: [MapPresence] = []
                for list in latestByPrefix.values {
                    for item in list {
                        guard seen.insert(item.providerId).inserted else { continue }
                        guard item.isVisibleOnCustomerMap else { continue }
                        let km = Self.distanceKm(from: center, to: item.coordinate)
                        guard km <= radiusKm else { continue }
                        merged.append(item)
                    }
                }
                merged.sort {
                    Self.distanceKm(from: center, to: $0.coordinate)
                        < Self.distanceKm(from: center, to: $1.coordinate)
                }
                continuation.yield(Array(merged.prefix(maxMarkers)))
            }

            for prefix in prefixes {
                let query = firestore.collection(MapPresenceConfig.collection)
                    .whereField("serviceType", isEqualTo: MapPresenceConfig.serviceTypeRide)
                    .whereField("status", isEqualTo: DriverOperationalStatus.available.rawValue)
                    .whereField("geohash", isGreaterThanOrEqualTo: prefix)
                    .whereField("geohash", isLessThanOrEqualTo: Geohash.upperBound(prefix))
                    .limit(to: 24)

                let listener = query.addSnapshotListener { snapshot, _ in
                    let items = snapshot?.documents.compactMap {
                        MapPresence(documentID: $0.documentID, data: $0.data())
                    } ?? []
                    latestByPrefix[prefix] = items
                    emit()
                }
                listeners.append(listener)
            }

            continuation.onTermination = { _ in
                listeners.forEach { $0.remove() }
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
