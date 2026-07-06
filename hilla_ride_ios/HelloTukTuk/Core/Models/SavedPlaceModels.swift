import CoreLocation
import FirebaseFirestore
import Foundation

struct SavedPlace: Identifiable, Equatable {
    let id: String
    let label: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var asMapPlace: MapPlace {
        MapPlace(label: label, coordinate: coordinate)
    }

    init(id: String, label: String, latitude: Double, longitude: Double, createdAt: Date? = nil) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        label = data["label"] as? String ?? ""
        latitude = (data["latitude"] as? NSNumber)?.doubleValue ?? 0
        longitude = (data["longitude"] as? NSNumber)?.doubleValue ?? 0
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = nil
        }
        guard !label.isEmpty else { return nil }
    }
}
