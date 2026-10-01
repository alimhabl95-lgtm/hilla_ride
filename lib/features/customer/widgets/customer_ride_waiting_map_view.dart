import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/services/nearby_providers_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/hilla_map_commands.dart';
import 'package:hilla_ride/core/widgets/map_camera_follow.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Map with pickup → destination road route while waiting for a driver.
class CustomerRideWaitingMapView extends StatefulWidget {
  const CustomerRideWaitingMapView({
    super.key,
    required this.ride,
    required this.bottomPanel,
    this.appBarTitle,
  });

  final Ride ride;
  final Widget bottomPanel;
  final String? appBarTitle;

  @override
  State<CustomerRideWaitingMapView> createState() =>
      _CustomerRideWaitingMapViewState();
}

class _CustomerRideWaitingMapViewState extends State<CustomerRideWaitingMapView> {
  final _routeService = DrivingDistanceService();
  final _cameraFollow = MapCameraFollowController();
  final _mapCommands = HillaMapCommands();
  GoogleMapController? _mapController;
  var _markersReady = false;
  var _didInitialFit = false;
  List<LatLng> _routePoints = const [];
  int? _etaMinutes;
  double? _distanceKm;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

  LatLng get _pickup =>
      LatLng(widget.ride.pickupLat, widget.ride.pickupLng);

  LatLng get _destination =>
      LatLng(widget.ride.destinationLat, widget.ride.destinationLng);

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(CustomerRideWaitingMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ride.id != widget.ride.id) {
      unawaited(_loadRoute());
    }
  }

  Future<void> _bootstrap() async {
    await MapMarkerIcons.ensureLoaded();
    if (!mounted) return;
    setState(() => _markersReady = true);
    await _loadMarkers();
    await _loadRoute();
  }

  Future<void> _loadMarkers() async {
    if (!_markersReady) return;
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
      _pickupIcon = icons[0];
      _destinationIcon = icons[1];
    });
  }

  Future<void> _loadRoute() async {
    try {
      final origin = ll.LatLng(_pickup.latitude, _pickup.longitude);
      final dest = ll.LatLng(_destination.latitude, _destination.longitude);
      final info = await _routeService.getDrivingRoute(origin, dest);
      final points = await _routeService.getRoutePolylinePoints(origin, dest);
      if (!mounted) return;
      setState(() {
        _etaMinutes = info.durationMinutes;
        _distanceKm = info.distanceKm;
        _routePoints = points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList(growable: false);
      });
    } catch (_) {
      final km = NearbyProvidersService.straightLineKm(
        ll.LatLng(_pickup.latitude, _pickup.longitude),
        ll.LatLng(_destination.latitude, _destination.longitude),
      );
      if (!mounted) return;
      setState(() {
        _distanceKm = km;
        _etaMinutes = NearbyProvidersService.estimateMinutes(km);
        _routePoints = [_pickup, _destination];
      });
    }
    if (!_didInitialFit) {
      _didInitialFit = true;
      if (_mapController != null) {
        unawaited(
          _cameraFollow.fitPoints(_mapController!, [_pickup, _destination]),
        );
      } else {
        unawaited(_mapCommands.fit());
      }
    }
  }

  Set<Marker> _buildMarkers() {
    if (!_markersReady ||
        _pickupIcon == null ||
        _destinationIcon == null) {
      return const {};
    }
    return {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        icon: _pickupIcon!,
        anchor: const Offset(0.5, 0.72),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: _destinationIcon!,
        anchor: const Offset(0.5, 0.72),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final polylines = _routePoints.length >= 2
        ? {
            Polyline(
              polylineId: const PolylineId('trip_route'),
              points: _routePoints,
              color: AppBrandAssets.brandTealDark,
              width: 5,
            ),
          }
        : <Polyline>{};

    return Scaffold(
      appBar: widget.appBarTitle == null
          ? null
          : AppBar(title: Text(widget.appBarTitle!)),
      extendBodyBehindAppBar: widget.appBarTitle != null,
      body: Stack(
        children: [
          GoogleMapView(
            initialPosition: _pickup,
            zoom: 14,
            markers: _buildMarkers(),
            polylines: polylines,
            commands: _mapCommands,
            onCameraMove: (_) => _cameraFollow.onUserCameraInteraction(),
            onMapCreated: (c) {
              _mapController = c;
              if (!_didInitialFit) {
                _didInitialFit = true;
                unawaited(_cameraFollow.fitPoints(c, [_pickup, _destination]));
              }
            },
          ),
          if (_etaMinutes != null && _distanceKm != null)
            Positioned(
              top: widget.appBarTitle == null ? AppSpacing.md : 56,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(AppRadii.md),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text(
                    l10n.localeName.startsWith('ar')
                        ? 'المسافة ~${_distanceKm!.toStringAsFixed(1)} كم · ~$_etaMinutes د'
                        : 'Trip ~${_distanceKm!.toStringAsFixed(1)} km · ~$_etaMinutes min',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppBrandAssets.brandNavy,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: widget.bottomPanel,
          ),
        ],
      ),
    );
  }
}
