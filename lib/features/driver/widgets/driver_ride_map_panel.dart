import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/map_camera_follow.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:provider/provider.dart';

class DriverRideMapPanel extends StatefulWidget {
  const DriverRideMapPanel({
    super.key,
    required this.ride,
    required this.driver,
  });

  final Ride ride;
  final DriverProfile driver;

  @override
  State<DriverRideMapPanel> createState() => _DriverRideMapPanelState();
}

class _DriverRideMapPanelState extends State<DriverRideMapPanel> {
  final _routeService = DrivingDistanceService();
  final _cameraFollow = MapCameraFollowController();
  gmaps.GoogleMapController? _mapController;
  var _markersReady = false;
  var _didInitialCameraFit = false;
  gmaps.BitmapDescriptor? _pickupMarkerIcon;
  gmaps.BitmapDescriptor? _destinationMarkerIcon;
  String? _loadedMarkerKey;

  List<gmaps.LatLng> _toPickupRoute = const [];
  List<gmaps.LatLng> _tripRoute = const [];
  var _loadingRoutes = true;
  String? _loadedTripKey;
  String? _loadedDriverKey;
  AppUser? _customer;
  StreamSubscription<AppUser?>? _customerSub;

  @override
  void initState() {
    super.initState();
    MapMarkerIcons.ensureLoaded().then((_) {
      if (mounted) setState(() => _markersReady = true);
      _loadTripMarkers();
    });
    _loadRoutes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchCustomer());
  }

  @override
  void dispose() {
    _customerSub?.cancel();
    super.dispose();
  }

  void _watchCustomer() {
    if (!mounted) return;
    final customerId = widget.ride.customerId;
    if (customerId.isEmpty) return;
    _customerSub?.cancel();
    _customerSub = context
        .read<AppState>()
        .authService
        .watchUser(customerId)
        .listen((user) {
      if (!mounted) return;
      setState(() => _customer = user);
    });
  }

  Future<void> _loadTripMarkers() async {
    if (!_markersReady || !mounted) return;
    final key =
        '${widget.ride.pickupLabel}|${widget.ride.destinationLabel}';
    if (_loadedMarkerKey == key &&
        _pickupMarkerIcon != null &&
        _destinationMarkerIcon != null) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final icons = await Future.wait([
      MapMarkerIcons.tripMarker(isPickup: true, label: l10n.pickup),
      MapMarkerIcons.tripMarker(
        isPickup: false,
        label: widget.ride.destinationLabel,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _pickupMarkerIcon = icons[0];
      _destinationMarkerIcon = icons[1];
      _loadedMarkerKey = key;
    });
  }

  @override
  void didUpdateWidget(covariant DriverRideMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.pickupLabel != widget.ride.pickupLabel ||
        oldWidget.ride.destinationLabel != widget.ride.destinationLabel) {
      _loadedMarkerKey = null;
      unawaited(_loadTripMarkers());
    }
    _loadRoutes();
  }

  latlng.LatLng get _pickup {
    final lat = _customer?.latitude;
    final lng = _customer?.longitude;
    if (lat != null && lng != null) {
      return latlng.LatLng(lat, lng);
    }
    return latlng.LatLng(widget.ride.pickupLat, widget.ride.pickupLng);
  }

  latlng.LatLng get _destination =>
      latlng.LatLng(widget.ride.destinationLat, widget.ride.destinationLng);

  latlng.LatLng? get _driverPosition {
    final lat = widget.driver.latitude;
    final lng = widget.driver.longitude;
    if (lat == null || lng == null) return null;
    return latlng.LatLng(lat, lng);
  }

  String get _tripKey =>
      '${widget.ride.pickupLat}|${widget.ride.pickupLng}|'
      '${widget.ride.destinationLat}|${widget.ride.destinationLng}';

  String get _driverKey {
    final pos = _driverPosition;
    if (pos == null) return 'none';
    return '${pos.latitude.toStringAsFixed(5)}|${pos.longitude.toStringAsFixed(5)}';
  }

  Future<void> _loadRoutes() async {
    final tripKey = _tripKey;
    final driverKey = _driverKey;
    final needsTrip = _loadedTripKey != tripKey;
    final needsDriver = _loadedDriverKey != driverKey;

    if (!needsTrip && !needsDriver) return;

    if (needsTrip || needsDriver) {
      setState(() => _loadingRoutes = true);
    }

    try {
      if (needsTrip) {
        final tripPoints = await _routeService.getRoutePolylinePoints(
          _pickup,
          _destination,
        );
        _tripRoute = _toGooglePoints(tripPoints);
        _loadedTripKey = tripKey;
      }

      if (needsDriver) {
        final driverPos = _driverPosition;
        if (driverPos != null) {
          final toPickupPoints = await _routeService.getRoutePolylinePoints(
            driverPos,
            _pickup,
          );
          _toPickupRoute = _toGooglePoints(toPickupPoints);
        } else {
          _toPickupRoute = const [];
        }
        _loadedDriverKey = driverKey;
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRoutes = false);
        // Routes/markers update freely — camera only on initial fit / Recenter.
        if (!_didInitialCameraFit && _mapController != null) {
          _didInitialCameraFit = true;
          unawaited(_fitCamera(force: true));
        }
      }
    }
  }

  List<gmaps.LatLng> _toGooglePoints(List<latlng.LatLng> points) {
    return points
        .map((point) => gmaps.LatLng(point.latitude, point.longitude))
        .toList();
  }

  Future<void> _fitCamera({bool force = false}) async {
    final controller = _mapController;
    if (controller == null) return;
    if (!force && !_cameraFollow.followEnabled) return;

    final points = <gmaps.LatLng>[
      gmaps.LatLng(widget.ride.pickupLat, widget.ride.pickupLng),
      gmaps.LatLng(widget.ride.destinationLat, widget.ride.destinationLng),
      ..._tripRoute,
      ..._toPickupRoute,
    ];

    final driverPos = _driverPosition;
    if (driverPos != null) {
      points.add(gmaps.LatLng(driverPos.latitude, driverPos.longitude));
    }

    if (points.isEmpty) return;
    await _cameraFollow.fitPoints(controller, points);
  }

  Set<gmaps.Marker> _buildMarkers(AppLocalizations l10n) {
    if (!_markersReady ||
        _pickupMarkerIcon == null ||
        _destinationMarkerIcon == null) {
      return const {};
    }

    final pickupPoint = _pickup;
    final pickup = gmaps.LatLng(pickupPoint.latitude, pickupPoint.longitude);
    final destination = gmaps.LatLng(
      widget.ride.destinationLat,
      widget.ride.destinationLng,
    );

    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('customer_pickup'),
        position: pickup,
        icon: _pickupMarkerIcon!,
        anchor: const Offset(0.5, 0.72),
        zIndexInt: 2,
        infoWindow: gmaps.InfoWindow(
          title: _customer?.latitude != null
              ? l10n.roleCustomer
              : l10n.pickup,
        ),
      ),
      gmaps.Marker(
        markerId: const gmaps.MarkerId('destination'),
        position: destination,
        icon: _destinationMarkerIcon!,
        anchor: const Offset(0.5, 0.72),
        zIndexInt: 2,
      ),
    };

    final driverPos = _driverPosition;
    if (driverPos != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('driver'),
          position: gmaps.LatLng(driverPos.latitude, driverPos.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
          infoWindow: gmaps.InfoWindow(title: l10n.roleDriver),
        ),
      );
    }

    return markers;
  }

  Set<gmaps.Polyline> _buildPolylines() {
    final polylines = <gmaps.Polyline>{};

    if (_toPickupRoute.length >= 2) {
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('driver_to_pickup'),
          points: _toPickupRoute,
          color: const Color(0xFF2563EB),
          width: 5,
        ),
      );
    }

    if (_tripRoute.length >= 2) {
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('pickup_to_destination'),
          points: _tripRoute,
          color: const Color(0xFF0F766E),
          width: 5,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final driverPos = _driverPosition;
    final center = driverPos != null
        ? gmaps.LatLng(driverPos.latitude, driverPos.longitude)
        : gmaps.LatLng(widget.ride.pickupLat, widget.ride.pickupLng);

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMapView(
            initialPosition: center,
            markers: _buildMarkers(l10n),
            polylines: _buildPolylines(),
            zoom: 14,
            onCameraMove: (_) => _cameraFollow.onUserCameraInteraction(),
            onMapCreated: (controller) {
              _mapController = controller;
              Future<void>.delayed(const Duration(milliseconds: 350), () {
                if (!mounted || _didInitialCameraFit) return;
                _didInitialCameraFit = true;
                unawaited(_fitCamera(force: true));
              });
            },
          ),
        ),
        Positioned(
          right: 12,
          bottom: 88,
          child: Material(
            color: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => unawaited(_fitCamera(force: true)),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.my_location,
                  color: AppBrandAssets.brandTealDark,
                ),
              ),
            ),
          ),
        ),
        if (_loadingRoutes)
          const Positioned(
            top: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _LegendDot(color: Color(0xFF16A34A), label: l10n.pickup),
                      const SizedBox(width: 12),
                      _LegendDot(
                        color: Color(0xFFDC2626),
                        label: l10n.destination,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _LegendDot(color: Color(0xFF2563EB), label: l10n.routeToPickup),
                      const SizedBox(width: 12),
                      _LegendDot(
                        color: Color(0xFF0F766E),
                        label: l10n.routeToDestination,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
