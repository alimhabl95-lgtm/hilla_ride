import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/services/nearby_providers_service.dart';
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

  List<gmaps.LatLng> _activeRoute = const [];
  var _loadingRoutes = true;
  String? _loadedRouteKey;
  RideStatus? _lastRideStatus;
  int? _etaMinutes;
  double? _distanceKm;
  DateTime? _lastRouteRefreshAt;
  latlng.LatLng? _lastRouteOrigin;
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
    if (oldWidget.ride.status != widget.ride.status) {
      _loadedRouteKey = null;
      _lastRouteOrigin = null;
      _lastRouteRefreshAt = null;
    }
    unawaited(_loadRoutes());
  }

  bool get _enRouteToPickup {
    final status = widget.ride.status;
    return status == RideStatus.accepted || status == RideStatus.matched;
  }

  bool get _onTripLeg {
    final status = widget.ride.status;
    return status == RideStatus.inProgress ||
        status == RideStatus.awaitingCashPayment;
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

  latlng.LatLng? get _routeDestination {
    if (_enRouteToPickup) return _pickup;
    if (_onTripLeg) return _destination;
    return null;
  }

  Future<void> _loadRoutes() async {
    final driverPos = _driverPosition;
    final dest = _routeDestination;
    if (driverPos == null || dest == null) {
      if (mounted) {
        setState(() {
          _activeRoute = const [];
          _loadingRoutes = false;
          _etaMinutes = null;
          _distanceKm = null;
        });
      }
      return;
    }

    final legKey = _enRouteToPickup ? 'pickup' : 'dest';
    final routeKey =
        '$legKey|${dest.latitude.toStringAsFixed(5)}|${dest.longitude.toStringAsFixed(5)}';

    final now = DateTime.now();
    final statusChanged = _lastRideStatus != widget.ride.status;
    final movedEnough = _lastRouteOrigin == null ||
        NearbyProvidersService.straightLineKm(_lastRouteOrigin!, driverPos) *
                1000 >=
            MapPresenceConfig.routeRefreshMinMoveMeters;
    final timedOut = _lastRouteRefreshAt == null ||
        now.difference(_lastRouteRefreshAt!) >=
            MapPresenceConfig.routeRefreshInterval;

    if (!statusChanged &&
        _loadedRouteKey == routeKey &&
        !movedEnough &&
        !timedOut) {
      return;
    }

    if (statusChanged || _loadedRouteKey != routeKey) {
      _loadedRouteKey = routeKey;
      _lastRouteOrigin = null;
      _lastRouteRefreshAt = null;
    }

    if (mounted) setState(() => _loadingRoutes = true);

    try {
      final info = await _routeService.getDrivingRoute(driverPos, dest);
      final points = await _routeService.getRoutePolylinePoints(driverPos, dest);
      if (!mounted) return;
      setState(() {
        _activeRoute = _toGooglePoints(points);
        _etaMinutes = info.durationMinutes;
        _distanceKm = info.distanceKm;
        _lastRouteRefreshAt = now;
        _lastRouteOrigin = driverPos;
        _lastRideStatus = widget.ride.status;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingRoutes = false);
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
      ..._activeRoute,
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
    if (_activeRoute.length < 2) return const {};
    final color = _enRouteToPickup
        ? const Color(0xFF2563EB)
        : const Color(0xFF0F766E);
    return {
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('active_route'),
        points: _activeRoute,
        color: color,
        width: 5,
      ),
    };
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
        if (_etaMinutes != null && _distanceKm != null)
          Positioned(
            top: 12,
            left: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppBrandAssets.brandTealDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_etaMinutes ${l10n.minutes}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.route,
                      size: 18,
                      color: AppBrandAssets.brandGold,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_distanceKm!.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
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
              child: Row(
                children: [
                  _LegendDot(color: const Color(0xFF16A34A), label: l10n.pickup),
                  const SizedBox(width: 12),
                  _LegendDot(
                    color: const Color(0xFFDC2626),
                    label: l10n.destination,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LegendDot(
                      color: _enRouteToPickup
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF0F766E),
                      label: _enRouteToPickup
                          ? l10n.routeToPickup
                          : l10n.routeToDestination,
                    ),
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
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
