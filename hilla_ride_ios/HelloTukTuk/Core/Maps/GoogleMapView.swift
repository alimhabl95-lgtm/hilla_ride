import CoreLocation
import GoogleMaps
import SwiftUI

struct GoogleMapView: UIViewRepresentable {
    let cameraTarget: CLLocationCoordinate2D
    let zoom: Float
    var pickup: MapPlace?
    var destination: MapPlace?
    var driverCoordinate: CLLocationCoordinate2D?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onCameraIdle: ((CLLocationCoordinate2D) -> Void)?
    var pinPickerMode = false

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress, onCameraIdle: onCameraIdle)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withTarget: cameraTarget, zoom: zoom)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.delegate = context.coordinator

        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(longPress)

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onCameraIdle = onCameraIdle
        mapView.clear()

        if pinPickerMode {
            if abs(mapView.camera.target.latitude - cameraTarget.latitude) > 0.00001 ||
                abs(mapView.camera.target.longitude - cameraTarget.longitude) > 0.00001 {
                mapView.camera = GMSCameraPosition.camera(withTarget: cameraTarget, zoom: zoom)
            }
            return
        }

        if let pickup {
            addMarker(
                on: mapView,
                coordinate: pickup.coordinate,
                title: pickup.label,
                color: .systemGreen
            )
        }

        if let destination {
            addMarker(
                on: mapView,
                coordinate: destination.coordinate,
                title: destination.label,
                color: .systemRed
            )
        }

        if let driverCoordinate {
            addMarker(
                on: mapView,
                coordinate: driverCoordinate,
                title: "Driver",
                color: .systemBlue
            )
        }

        if pickup != nil && destination != nil {
            var bounds = GMSCoordinateBounds()
            if let pickup { bounds = bounds.includingCoordinate(pickup.coordinate) }
            if let destination { bounds = bounds.includingCoordinate(destination.coordinate) }
            let update = GMSCameraUpdate.fit(bounds, withPadding: 80)
            mapView.animate(with: update)
        } else if mapView.camera.target.latitude != cameraTarget.latitude ||
                    mapView.camera.target.longitude != cameraTarget.longitude {
            mapView.animate(toLocation: cameraTarget)
        }
    }

    private func addMarker(
        on mapView: GMSMapView,
        coordinate: CLLocationCoordinate2D,
        title: String,
        color: UIColor
    ) {
        let marker = GMSMarker(position: coordinate)
        marker.title = title
        marker.icon = GMSMarker.markerImage(with: color)
        marker.map = mapView
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var onCameraIdle: ((CLLocationCoordinate2D) -> Void)?

        init(
            onLongPress: ((CLLocationCoordinate2D) -> Void)?,
            onCameraIdle: ((CLLocationCoordinate2D) -> Void)?
        ) {
            self.onLongPress = onLongPress
            self.onCameraIdle = onCameraIdle
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? GMSMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.projection.coordinate(for: point)
            onLongPress?(coordinate)
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            onCameraIdle?(position.target)
        }
    }
}
