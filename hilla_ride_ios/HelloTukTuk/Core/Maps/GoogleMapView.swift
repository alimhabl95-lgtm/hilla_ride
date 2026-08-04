import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

struct MapDriverMarker: Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let heading: Double

    static func == (lhs: MapDriverMarker, rhs: MapDriverMarker) -> Bool {
        lhs.id == rhs.id
            && abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 0.0000001
            && abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 0.0000001
            && abs(lhs.heading - rhs.heading) < 0.1
    }
}

struct GoogleMapView: UIViewRepresentable {
    let cameraTarget: CLLocationCoordinate2D
    let zoom: Float
    var pickup: MapPlace?
    var destination: MapPlace?
    var driverCoordinate: CLLocationCoordinate2D?
    var driverHeading: Double = 0
    var nearbyDrivers: [MapDriverMarker] = []
    var routePath: [CLLocationCoordinate2D] = []
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
        context.coordinator.startAnimating()
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onCameraIdle = onCameraIdle
        context.coordinator.mapView = mapView

        if pinPickerMode {
            if abs(mapView.camera.target.latitude - cameraTarget.latitude) > 0.00001 ||
                abs(mapView.camera.target.longitude - cameraTarget.longitude) > 0.00001 {
                mapView.camera = GMSCameraPosition.camera(withTarget: cameraTarget, zoom: zoom)
            }
            return
        }

        // Static pins (pickup / destination) redraw when needed.
        context.coordinator.syncStaticMarkers(
            pickup: pickup,
            destination: destination,
            on: mapView
        )

        var drivers = nearbyDrivers
        if let driverCoordinate {
            drivers = [
                MapDriverMarker(
                    id: "assigned",
                    coordinate: driverCoordinate,
                    heading: driverHeading
                )
            ]
        }
        context.coordinator.syncDrivers(drivers, on: mapView)
        context.coordinator.syncRoute(routePath, on: mapView)

        if pickup != nil && destination != nil {
            var bounds = GMSCoordinateBounds()
            if let pickup { bounds = bounds.includingCoordinate(pickup.coordinate) }
            if let destination { bounds = bounds.includingCoordinate(destination.coordinate) }
            if let driverCoordinate {
                bounds = bounds.includingCoordinate(driverCoordinate)
            }
            let update = GMSCameraUpdate.fit(bounds, withPadding: 80)
            mapView.animate(with: update)
        } else if mapView.camera.target.latitude != cameraTarget.latitude ||
                    mapView.camera.target.longitude != cameraTarget.longitude {
            mapView.animate(toLocation: cameraTarget)
        }
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var onCameraIdle: ((CLLocationCoordinate2D) -> Void)?
        weak var mapView: GMSMapView?
        private var pickupMarker: GMSMarker?
        private var destinationMarker: GMSMarker?
        private var driverMarkers: [String: GMSMarker] = [:]
        private var targets: [String: MapDriverMarker] = [:]
        private var routePolyline: GMSPolyline?
        private var displayLink: CADisplayLink?
        private var lastTick: CFTimeInterval = 0

        init(
            onLongPress: ((CLLocationCoordinate2D) -> Void)?,
            onCameraIdle: ((CLLocationCoordinate2D) -> Void)?
        ) {
            self.onLongPress = onLongPress
            self.onCameraIdle = onCameraIdle
        }

        func startAnimating() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func tick(link: CADisplayLink) {
            let dt = lastTick == 0 ? 0.016 : link.timestamp - lastTick
            lastTick = link.timestamp
            let duration = MapPresenceConfig.markerAnimationDuration
            for (id, marker) in driverMarkers {
                guard let target = targets[id] else { continue }
                let current = marker.position
                let goal = target.coordinate
                let latDelta = goal.latitude - current.latitude
                let lngDelta = goal.longitude - current.longitude
                let dist = abs(latDelta) + abs(lngDelta)
                if dist < 0.0000005 {
                    marker.position = goal
                    marker.rotation = target.heading
                    continue
                }
                let t = min(1, dt / duration)
                let eased = 1 - pow(1 - t, 3)
                marker.position = CLLocationCoordinate2D(
                    latitude: current.latitude + latDelta * eased,
                    longitude: current.longitude + lngDelta * eased
                )
                marker.rotation = lerpHeading(marker.rotation, target.heading, eased)
            }
        }

        private func lerpHeading(_ a: CLLocationDegrees, _ b: CLLocationDegrees, _ t: Double) -> CLLocationDegrees {
            var delta = (b - a).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            return (a + delta * t).truncatingRemainder(dividingBy: 360)
        }

        func syncStaticMarkers(pickup: MapPlace?, destination: MapPlace?, on mapView: GMSMapView) {
            if let pickup {
                if pickupMarker == nil {
                    let marker = GMSMarker(position: pickup.coordinate)
                    marker.icon = GMSMarker.markerImage(with: .systemGreen)
                    marker.map = mapView
                    pickupMarker = marker
                }
                pickupMarker?.position = pickup.coordinate
                pickupMarker?.title = pickup.label
            } else {
                pickupMarker?.map = nil
                pickupMarker = nil
            }

            if let destination {
                if destinationMarker == nil {
                    let marker = GMSMarker(position: destination.coordinate)
                    marker.icon = GMSMarker.markerImage(with: .systemRed)
                    marker.map = mapView
                    destinationMarker = marker
                }
                destinationMarker?.position = destination.coordinate
                destinationMarker?.title = destination.label
            } else {
                destinationMarker?.map = nil
                destinationMarker = nil
            }
        }

        func syncDrivers(_ drivers: [MapDriverMarker], on mapView: GMSMapView) {
            let ids = Set(drivers.map(\.id))
            for (id, marker) in driverMarkers where !ids.contains(id) {
                marker.map = nil
                driverMarkers[id] = nil
                targets[id] = nil
            }
            for driver in drivers {
                targets[driver.id] = driver
                if let existing = driverMarkers[driver.id] {
                    // Animation loop moves toward target.
                    _ = existing
                } else {
                    let marker = GMSMarker(position: driver.coordinate)
                    marker.icon = TukTukMapMarker.image
                    marker.groundAnchor = CGPoint(x: 0.5, y: 0.55)
                    marker.isFlat = true
                    marker.rotation = driver.heading
                    marker.map = mapView
                    driverMarkers[driver.id] = marker
                }
            }
        }

        func syncRoute(_ path: [CLLocationCoordinate2D], on mapView: GMSMapView) {
            guard path.count >= 2 else {
                routePolyline?.map = nil
                routePolyline = nil
                return
            }
            let gmsPath = GMSMutablePath()
            path.forEach { gmsPath.add($0) }
            if routePolyline == nil {
                let line = GMSPolyline(path: gmsPath)
                line.strokeColor = UIColor(red: 15 / 255, green: 118 / 255, blue: 110 / 255, alpha: 1)
                line.strokeWidth = 5
                line.map = mapView
                routePolyline = line
            } else {
                routePolyline?.path = gmsPath
            }
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

/// Official Hello Tuk-Tuk map marker — asset only, no status labels.
enum TukTukMapMarker {
    static let image: UIImage = {
        let base = UIImage(named: "TukTukMapMarker") ?? proceduralFallback()
        let targetWidth: CGFloat = 96
        let scale = targetWidth / max(base.size.width, 1)
        let size = CGSize(width: targetWidth, height: base.size.height * scale)
        let pad: CGFloat = 8
        let canvas = CGSize(width: size.width + pad * 2, height: size.height + pad * 2)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.black.withAlphaComponent(0.18).cgColor)
            cg.fillEllipse(
                in: CGRect(
                    x: canvas.width * 0.22,
                    y: canvas.height * 0.82,
                    width: canvas.width * 0.56,
                    height: canvas.height * 0.12
                )
            )
            base.draw(in: CGRect(x: pad, y: pad, width: size.width, height: size.height))
        }
    }()

    private static func proceduralFallback() -> UIImage {
        let size = CGSize(width: 72, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            let w = size.width
            let h = size.height
            cg.setFillColor(UIColor.black.withAlphaComponent(0.15).cgColor)
            cg.fillEllipse(in: CGRect(x: w * 0.22, y: h * 0.78, width: w * 0.56, height: h * 0.12))
            UIColor(red: 34 / 255, green: 139 / 255, blue: 34 / 255, alpha: 1).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: w * 0.2, y: h * 0.2, width: w * 0.6, height: h * 0.55),
                cornerRadius: 10
            ).fill()
            UIColor(red: 1, green: 196 / 255, blue: 0, alpha: 1).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: w * 0.28, y: h * 0.24, width: w * 0.44, height: h * 0.22),
                cornerRadius: 6
            ).fill()
        }
    }
}
