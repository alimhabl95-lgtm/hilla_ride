import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/widgets/hilla_map_commands.dart';
import 'package:latlong2/latlong.dart' as ll;

class GoogleMapView extends StatefulWidget {
  const GoogleMapView({
    super.key,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.onMapCreated,
    this.onCameraIdle,
    this.onCameraMove,
    this.commands,
    this.zoom = 14,
  });

  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController controller)? onMapCreated;
  final VoidCallback? onCameraIdle;
  final void Function(CameraPosition position)? onCameraMove;
  final HillaMapCommands? commands;
  final double zoom;

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  var _myLocationEnabled = false;
  final _osmController = fm.MapController();
  var _osmReady = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    unawaited(_enableMyLocationWhenPermitted());
  }

  @override
  void didUpdateWidget(covariant GoogleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isAndroid && _osmReady) {
      unawaited(_fitOsmIfNeeded(oldWidget));
    }
  }

  @override
  void dispose() {
    if (_isAndroid) {
      _osmController.dispose();
    }
    super.dispose();
  }

  Future<void> _enableMyLocationWhenPermitted() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!mounted || !granted || _myLocationEnabled) return;
      setState(() => _myLocationEnabled = true);
    } catch (error) {
      debugPrint('Map location layer skipped: $error');
    }
  }

  List<ll.LatLng> _overlayPoints() {
    final points = <ll.LatLng>[];
    for (final line in widget.polylines) {
      for (final point in line.points) {
        points.add(ll.LatLng(point.latitude, point.longitude));
      }
    }
    for (final marker in widget.markers) {
      points.add(
        ll.LatLng(marker.position.latitude, marker.position.longitude),
      );
    }
    if (points.isEmpty) {
      points.add(
        ll.LatLng(
          widget.initialPosition.latitude,
          widget.initialPosition.longitude,
        ),
      );
    }
    return points;
  }

  Future<void> _fitOsmIfNeeded(GoogleMapView oldWidget) async {
    final routeGrew = widget.polylines.length != oldWidget.polylines.length ||
        widget.polylines.any(
          (line) => !oldWidget.polylines.any(
            (old) =>
                old.polylineId == line.polylineId &&
                old.points.length == line.points.length,
          ),
        );
    if (!routeGrew && widget.markers.length == oldWidget.markers.length) {
      return;
    }
    _fitOsm();
  }

  void _fitOsm() {
    final points = _overlayPoints();
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _osmController.move(points.first, math.max(widget.zoom, 15));
        return;
      }
      _osmController.fitCamera(
        fm.CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    } catch (error) {
      debugPrint('Android street-map fit failed: $error');
    }
  }

  Widget _androidStreetFallback() {
    final center = ll.LatLng(
      widget.initialPosition.latitude,
      widget.initialPosition.longitude,
    );
    return fm.FlutterMap(
      mapController: _osmController,
      options: fm.MapOptions(
        initialCenter: center,
        initialZoom: widget.zoom,
        onMapReady: () {
          _osmReady = true;
          _fitOsm();
        },
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            widget.onCameraMove?.call(
              CameraPosition(
                target: LatLng(
                  position.center.latitude,
                  position.center.longitude,
                ),
                zoom: position.zoom,
              ),
            );
          }
        },
      ),
      children: [
        fm.TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.hillaride.hilla_ride',
          maxNativeZoom: 19,
          maxZoom: 19,
        ),
        if (widget.polylines.isNotEmpty)
          fm.PolylineLayer(
            polylines: widget.polylines
                .where((line) => line.points.length >= 2)
                .map(
                  (line) => fm.Polyline(
                    points: line.points
                        .map(
                          (point) =>
                              ll.LatLng(point.latitude, point.longitude),
                        )
                        .toList(),
                    color: line.color,
                    strokeWidth: line.width.toDouble().clamp(4, 8),
                  ),
                )
                .toList(),
          ),
        fm.MarkerLayer(
          markers: widget.markers.map(_toOsmMarker).toList(),
        ),
      ],
    );
  }

  fm.Marker _toOsmMarker(Marker marker) {
    final id = marker.markerId.value;
    final isDriver = id == 'driver';
    return fm.Marker(
      point: ll.LatLng(marker.position.latitude, marker.position.longitude),
      width: isDriver ? 44 : 34,
      height: isDriver ? 44 : 34,
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: (marker.rotation * math.pi) / 180,
        child: _markerChild(id),
      ),
    );
  }

  Widget _markerChild(String id) {
    if (id == 'driver') {
      return const Icon(
        Icons.airport_shuttle,
        color: Color(0xFF0F766E),
        size: 36,
      );
    }
    final isPickup = id.contains('pickup') || id == 'customer_pickup';
    final color = isPickup ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Android WebView maps punch a black surface over the whole app.
    if (_isAndroid) {
      return _androidStreetFallback();
    }

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
      buildingsEnabled: true,
      initialCameraPosition: CameraPosition(
        target: widget.initialPosition,
        zoom: widget.zoom,
      ),
      myLocationEnabled: _myLocationEnabled,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      liteModeEnabled: false,
      markers: widget.markers,
      polylines: widget.polylines,
      onMapCreated: (controller) {
        widget.onMapCreated?.call(controller);
      },
      onCameraIdle: widget.onCameraIdle,
      onCameraMove: widget.onCameraMove,
    );
  }
}
