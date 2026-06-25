import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/config/maps_config.dart';

class GoogleMapView extends StatelessWidget {
  const GoogleMapView({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onCameraIdle,
    this.onCameraMove,
    this.zoom = 14,
  });

  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onCameraIdle;
  final void Function(CameraPosition position)? onCameraMove;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    if (!MapsConfig.isConfigured) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Text(
          'Add your Google Maps API key in lib/core/config/maps_config.dart '
          'and android/app/src/main/AndroidManifest.xml',
          textAlign: TextAlign.center,
        ),
      );
    }

    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: zoom,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: markers,
      polylines: polylines,
      onMapCreated: onMapCreated,
      onCameraIdle: onCameraIdle,
      onCameraMove: onCameraMove,
    );
  }
}
