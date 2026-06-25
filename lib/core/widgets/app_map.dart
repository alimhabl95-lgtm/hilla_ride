import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:latlong2/latlong.dart';

class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.mapController,
    this.center = HillaConstants.cityCenter,
    this.zoom = HillaConstants.defaultMapZoom,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.onMapReady,
  });

  final MapController mapController;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final void Function(TapPosition, LatLng)? onTap;
  final VoidCallback? onMapReady;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: onTap,
        onMapReady: onMapReady,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.hillaride.hilla_ride',
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}
