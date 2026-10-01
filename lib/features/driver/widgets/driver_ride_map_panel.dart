import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/services/nearby_providers_service.dart';
import 'package:hilla_ride/core/services/turn_by_turn_guide.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/hilla_map_commands.dart';
import 'package:hilla_ride/core/widgets/map_camera_follow.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/core/widgets/marker_animator.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' as latlng;

class DriverRideMapPanel extends StatefulWidget {
  const DriverRideMapPanel({
    super.key,
    required this.ride,
    this.driver,
  });

  final Ride ride;
  final DriverProfile? driver;

  @override
  State<DriverRideMapPanel> createState() => _DriverRideMapPanelState();
}

class _DriverRideMapPanelState extends State<DriverRideMapPanel> {
  final _routeService = DrivingDistanceService();
  final _cameraFollow = MapCameraFollowController();
  final _mapCommands = HillaMapCommands();
  gmaps.GoogleMapController? _mapController;
  var _markersReady = false;
  var _didInitialCameraFit = false;
  gmaps.BitmapDescriptor? _pickupMarkerIcon;
  gmaps.BitmapDescriptor? _destinationMarkerIcon;
  String? _loadedMarkerKey;

  List<gmaps.LatLng> _activeRoute = const [];
  List<latlng.LatLng> _routeLatLng = const [];
  List<NavigationStep> _steps = const [];
  var _routeIsEstimated = false;
  TurnCue? _cue;
  var _loadingRoutes = false;
  String? _loadedRouteKey;
  RideStatus? _lastRideStatus;
  int? _etaMinutes;
  double? _distanceKm;
  DateTime? _lastRerouteAt;
  var _routeRequestId = 0;
  latlng.LatLng? _liveFix;
  StreamSubscription<Position>? _gpsSub;
  final _markerAnimator = MarkerAnimator();

  @override
  void initState() {
    super.initState();
    _markerAnimator.onTick = () {
      if (mounted) setState(() {});
    };
    MapMarkerIcons.ensureLoaded().then((_) {
      if (mounted) setState(() => _markersReady = true);
      unawaited(_loadTripMarkers());
    });
    unawaited(_loadRoutes(force: true));
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (!mounted) return;
      final fix = latlng.LatLng(position.latitude, position.longitude);
      setState(() => _liveFix = fix);
      _syncDriverMarker(fix, position.heading);
      _updateCue(fix);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    unawaited(_gpsSub?.cancel());
    _markerAnimator.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DriverRideMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.pickupLabel != widget.ride.pickupLabel ||
        oldWidget.ride.destinationLabel != widget.ride.destinationLabel) {
      _loadedMarkerKey = null;
      unawaited(_loadTripMarkers());
    }

    final statusChanged = oldWidget.ride.status != widget.ride.status;
    if (statusChanged) {
      _loadedRouteKey = null;
      _didInitialCameraFit = false;
      _cue = null;
      unawaited(_loadRoutes(force: true));
      return;
    }

    final profile = _profilePosition;
    if (_liveFix == null && profile != null) {
      _syncDriverMarker(profile, widget.driver?.heading ?? 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateCue(profile);
      });
    }
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

  bool get _enRouteToPickup {
    final status = widget.ride.status;
    return status == RideStatus.accepted || status == RideStatus.matched;
  }

  bool get _onTripLeg {
    final status = widget.ride.status;
    return status == RideStatus.inProgress ||
        status == RideStatus.awaitingCashPayment;
  }

  latlng.LatLng get _pickup =>
      latlng.LatLng(widget.ride.pickupLat, widget.ride.pickupLng);

  latlng.LatLng get _destination =>
      latlng.LatLng(widget.ride.destinationLat, widget.ride.destinationLng);

  latlng.LatLng? get _profilePosition {
    final lat = widget.driver?.latitude;
    final lng = widget.driver?.longitude;
    if (lat == null || lng == null) return null;
    return latlng.LatLng(lat, lng);
  }

  latlng.LatLng? get _driverPosition => _liveFix ?? _profilePosition;

  void _syncDriverMarker(latlng.LatLng position, double heading) {
    _markerAnimator.syncTargets({
      'driver': (
        position: gmaps.LatLng(position.latitude, position.longitude),
        heading: heading.isFinite && heading >= 0 ? heading : 0,
      ),
    });
  }

  void _updateCue(latlng.LatLng driverPos) {
    final cue = TurnByTurnGuide.evaluate(
      steps: _steps,
      polyline: _routeLatLng,
      driver: driverPos,
      isEstimated: _routeIsEstimated,
    );
    if (!mounted) return;
    setState(() {
      _cue = cue;
      if (cue != null && !cue.offRoute) {
        _distanceKm = cue.remainingMeters / 1000;
        _etaMinutes = cue.remainingMinutes;
      }
    });
    if (cue != null && cue.offRoute) {
      final now = DateTime.now();
      if (_lastRerouteAt == null ||
          now.difference(_lastRerouteAt!) >= const Duration(seconds: 8)) {
        _lastRerouteAt = now;
        unawaited(_loadRoutes(force: true));
      }
    }
  }

  latlng.LatLng? get _routeDestination {
    if (_enRouteToPickup) return _pickup;
    if (_onTripLeg) return _destination;
    return null;
  }

  Future<void> _loadRoutes({bool force = false}) async {
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

    final statusChanged = _lastRideStatus != widget.ride.status;

    if (!force && !statusChanged && _loadedRouteKey == routeKey) {
      return;
    }

    final requestId = ++_routeRequestId;
    if (mounted) setState(() => _loadingRoutes = true);
    final languageCode =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar';

    try {
      final info = await _routeService.getDrivingRouteDetails(
        driverPos,
        dest,
        languageCode: languageCode,
      );
      if (!mounted || requestId != _routeRequestId) return;

      final points = info.polylinePoints.length >= 2
          ? info.polylinePoints
          : [driverPos, dest];

      setState(() {
        _routeLatLng = points;
        _steps = info.steps;
        _routeIsEstimated = info.isEstimated;
        _activeRoute = _toGooglePoints(points);
        _etaMinutes = info.durationMinutes;
        _distanceKm = info.distanceKm;
        _lastRideStatus = widget.ride.status;
        _loadedRouteKey = routeKey;
        _loadingRoutes = false;
      });
      _updateCue(driverPos);

      if (!_didInitialCameraFit &&
          (_mapController != null || _mapCommands.canFit)) {
        _didInitialCameraFit = true;
        unawaited(_fitCamera(force: true));
      } else if (_cameraFollow.followEnabled) {
        unawaited(_fitCamera());
      }
    } catch (_) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeLatLng = [driverPos, dest];
        _steps = const [];
        _routeIsEstimated = true;
        _activeRoute = _toGooglePoints([driverPos, dest]);
        final km =
            NearbyProvidersService.straightLineKm(driverPos, dest);
        _distanceKm = km;
        _etaMinutes = NearbyProvidersService.estimateMinutes(km);
        _lastRideStatus = widget.ride.status;
        _loadedRouteKey = routeKey;
        _loadingRoutes = false;
      });
    }
  }

  List<gmaps.LatLng> _toGooglePoints(List<latlng.LatLng> points) {
    return points
        .map((point) => gmaps.LatLng(point.latitude, point.longitude))
        .toList();
  }

  Future<void> _fitCamera({bool force = false}) async {
    if (!force && !_cameraFollow.followEnabled) return;
    final controller = _mapController;
    if (controller == null) {
      await _mapCommands.fit();
      return;
    }

    final points = <gmaps.LatLng>[..._activeRoute];
    final driverPos = _driverPosition;
    final dest = _routeDestination;
    if (driverPos != null) {
      points.add(gmaps.LatLng(driverPos.latitude, driverPos.longitude));
    }
    if (dest != null) {
      points.add(gmaps.LatLng(dest.latitude, dest.longitude));
    }

    if (points.isEmpty) {
      points.add(gmaps.LatLng(widget.ride.pickupLat, widget.ride.pickupLng));
      points.add(
        gmaps.LatLng(widget.ride.destinationLat, widget.ride.destinationLng),
      );
    }

    await _cameraFollow.fitPoints(controller, points);
  }

  Set<gmaps.Marker> _buildMarkers(AppLocalizations l10n) {
    if (!_markersReady ||
        _pickupMarkerIcon == null ||
        _destinationMarkerIcon == null) {
      return const {};
    }

    final pickup = gmaps.LatLng(widget.ride.pickupLat, widget.ride.pickupLng);
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
        infoWindow: gmaps.InfoWindow(title: l10n.pickup),
      ),
      gmaps.Marker(
        markerId: const gmaps.MarkerId('destination'),
        position: destination,
        icon: _destinationMarkerIcon!,
        anchor: const Offset(0.5, 0.72),
        zIndexInt: 2,
        infoWindow: gmaps.InfoWindow(title: l10n.destination),
      ),
    };

    final animated = _markerAnimator.markers['driver'];
    final driverIcon = MapMarkerIcons.driver;
    if (animated != null && driverIcon != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('driver'),
          position: animated.position,
          icon: driverIcon,
          rotation: animated.heading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 3,
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
            commands: _mapCommands,
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
        if (_cue != null && _cue!.instruction.isNotEmpty)
          Positioned(
            top: 12,
            left: 12,
            right: 72,
            child: Card(
              color: const Color(0xFF0F766E),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _maneuverIcon(_cue!.maneuver),
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _cue!.offRoute
                                ? (l10n.localeName.startsWith('ar')
                                    ? 'إعادة حساب المسار'
                                    : 'Recalculating route')
                                : _cue!.instruction,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.localeName.startsWith('ar')
                                ? 'بعد ${TurnByTurnGuide.formatDistance(_cue!.metersToManeuver, arabic: true)}'
                                : 'in ${TurnByTurnGuide.formatDistance(_cue!.metersToManeuver, arabic: false)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_etaMinutes != null && _distanceKm != null)
          Positioned(
            top: _cue != null && _cue!.instruction.isNotEmpty ? 92 : 12,
            left: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
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
                    const Icon(
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

  IconData _maneuverIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Icons.turn_right;
      case 'turn-left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Icons.turn_left;
      case 'uturn-left':
      case 'uturn-right':
        return Icons.u_turn_left;
      case 'roundabout-left':
      case 'roundabout-right':
        return Icons.roundabout_right;
      case 'merge':
      case 'fork-left':
      case 'fork-right':
        return Icons.fork_right;
      default:
        return Icons.straight;
    }
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
