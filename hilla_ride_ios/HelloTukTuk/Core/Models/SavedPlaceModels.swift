import CoreLocation
import FirebaseFirestore
import Foundation

enum SavedPlaceType: String {
    case home
    case work
    case other

    static func from(_ raw: String?) -> SavedPlaceType {
        guard let raw else { return .other }
        return SavedPlaceType(rawValue: raw) ?? .other
    }
}

struct SavedPlace: Identifiable, Equatable {
    let id: String
    let label: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date?
    let placeType: SavedPlaceType

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var asMapPlace: MapPlace {
        MapPlace(label: label, coordinate: coordinate)
    }

    var isHome: Bool { placeType == .home }
    var isWork: Bool { placeType == .work }

    init(
        id: String,
        label: String,
        latitude: Double,
        longitude: Double,
        createdAt: Date? = nil,
        placeType: SavedPlaceType = .other
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.placeType = placeType
    }

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        label = data["label"] as? String ?? ""
        latitude = (data["latitude"] as? NSNumber)?.doubleValue ?? 0
        longitude = (data["longitude"] as? NSNumber)?.doubleValue ?? 0
        placeType = SavedPlaceType.from(data["placeType"] as? String)
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = nil
        }
        guard !label.isEmpty else { return nil }
    }
}
