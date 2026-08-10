import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/driving_distance_service.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/nearby_providers_service.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/core/widgets/map_camera_follow.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/core/widgets/marker_animator.dart';
import 'package:hilla_ride/features/customer/customer_ride_actions.dart';
import 'package:hilla_ride/features/customer/screens/trip_completed_screen.dart';
import 'package:hilla_ride/features/shared/screens/ride_chat_screen.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackDriverScreen extends StatefulWidget {
  const TrackDriverScreen({
    super.key,
    required this.rideId,
    this.embedded = false,
  });

  final String rideId;
  final bool embedded;

  @override
  State<TrackDriverScreen> createState() => _TrackDriverScreenState();
}

class _TrackDriverScreenState extends State<TrackDriverScreen> {
  GoogleMapController? _mapController;
  static const _fareService = FareService();
  final _routeService = DrivingDistanceService();
  final _markerAnimator = MarkerAnimator();
  final _cameraFollow = MapCameraFollowController();
  var _markersReady = false;
  var _didInitialCameraFit = false;
  List<LatLng> _lastCameraPoints = const [];
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;
  String? _loadedMarkerKey;
  List<LatLng> _routePoints = const [];
  int? _etaMinutes;
  double? _distanceKm;
  DateTime? _lastRouteRefreshAt;
  LatLng? _lastRouteOrigin;
  String? _lastRouteKey;

  @override
  void initState() {
    super.initState();
    _markerAnimator.onTick = () {
      if (mounted) setState(() {});
    };
    MapMarkerIcons.ensureLoaded().then((_) {
      if (mounted) setState(() => _markersReady = true);
    });
  }

  @override
  void dispose() {
    _markerAnimator.dispose();
    super.dispose();
  }

  Future<void> _loadTripMarkers({
    required String pickupLabel,
    required String destinationLabel,
  }) async {
    if (!_markersReady) return;
    final key = '$pickupLabel|$destinationLabel';
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
        label: destinationLabel,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _pickupMarkerIcon = icons[0];
      _destinationMarkerIcon = icons[1];
      _loadedMarkerKey = key;
    });
  }

  Future<void> _recenterCamera(Iterable<LatLng> points) async {
    final controller = _mapController;
    if (controller == null) return;
    final list = points.toList();
    if (list.isEmpty) return;
    _lastCameraPoints = list;
    await _cameraFollow.fitPoints(controller, list);
  }

  Future<void> _refreshRoute({
    required Ride ride,
    required LatLng driverPos,
  }) async {
    final toPickup = ride.status == RideStatus.accepted;
    final destination = toPickup
        ? LatLng(ride.pickupLat, ride.pickupLng)
        : LatLng(ride.destinationLat, ride.destinationLng);
    final routeKey =
        '${toPickup ? 'pickup' : 'dest'}|${destination.latitude}|${destination.longitude}';

    final now = DateTime.now();
    final movedEnough = _lastRouteOrigin == null ||
        GeolocatorLite.distanceMeters(_lastRouteOrigin!, driverPos) >=
            MapPresenceConfig.routeRefreshMinMoveMeters;
    final timedOut = _lastRouteRefreshAt == null ||
        now.difference(_lastRouteRefreshAt!) >=
            MapPresenceConfig.routeRefreshInterval;
    if (_lastRouteKey == routeKey && !movedEnough && !timedOut) return;

    _lastRouteKey = routeKey;
    _lastRouteRefreshAt = now;
    _lastRouteOrigin = driverPos;

    try {
      final origin = ll.LatLng(driverPos.latitude, driverPos.longitude);
      final dest = ll.LatLng(destination.latitude, destination.longitude);
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
        ll.LatLng(driverPos.latitude, driverPos.longitude),
        ll.LatLng(destination.latitude, destination.longitude),
      );
      if (!mounted) return;
      setState(() {
        _distanceKm = km;
        _etaMinutes = NearbyProvidersService.estimateMinutes(km);
        _routePoints = [driverPos, destination];
      });
    }
  }

  Set<Marker> _buildMarkers({
    required LatLng pickup,
    required LatLng destination,
  }) {
    if (!_markersReady ||
        _pickupMarkerIcon == null ||
        _destinationMarkerIcon == null) {
      return const {};
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: _pickupMarkerIcon!,
        anchor: const Offset(0.5, 0.72),
        zIndexInt: 2,
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: _destinationMarkerIcon!,
        anchor: const Offset(0.5, 0.72),
        zIndexInt: 2,
      ),
    };

    final driverIcon = MapMarkerIcons.driver;
    final animated = _markerAnimator.markers['driver'];
    if (driverIcon != null && animated != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: animated.position,
          icon: driverIcon,
          rotation: animated.heading,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 3,
        ),
      );
    }

    return markers;
  }

  Future<void> _callDriver(String? phone) async {
    final raw = (phone ?? '').trim();
    if (raw.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: raw);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    final driverService = context.read<AppState>().driverService;
    final authService = context.read<AppState>().authService;
    final currentUser = authService.currentUser;
    final isArabic = l10n.localeName.startsWith('ar');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackDriverTitle)),
      body: StreamBuilder<Ride?>(
        stream: rideService.watchRide(widget.rideId),
        builder: (context, rideSnapshot) {
          final ride = rideSnapshot.data;
          if (ride == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ride.status == RideStatus.cancelled && !widget.embedded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            });
            return const SizedBox.shrink();
          }

          if (ride.status == RideStatus.completed && !widget.embedded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TripCompletedScreen(rideId: widget.rideId),
                ),
              );
            });
          }

          final driverId = ride.driverId;
          if (driverId == null) {
            return Center(child: Text(l10n.searchingDriver));
          }

          return StreamBuilder<DriverProfile?>(
            stream: driverService.watchDriverLocation(driverId),
            builder: (context, driverSnapshot) {
              final driver = driverSnapshot.data;
              final pickup = LatLng(ride.pickupLat, ride.pickupLng);
              final destination =
                  LatLng(ride.destinationLat, ride.destinationLng);
              LatLng? driverPos;
              if (driver?.latitude != null && driver?.longitude != null) {
                driverPos = LatLng(driver!.latitude!, driver.longitude!);
                _markerAnimator.syncTargets({
                  'driver': (
                    position: driverPos,
                    heading: driver.heading,
                  ),
                });
                unawaited(_refreshRoute(ride: ride, driverPos: driverPos));
              } else {
                _markerAnimator.syncTargets({});
              }

              unawaited(_loadTripMarkers(
                pickupLabel: ride.pickupLabel,
                destinationLabel: ride.destinationLabel,
              ));

              final animatedPos =
                  _markerAnimator.markers['driver']?.position ?? driverPos;
              final cameraPoints = <LatLng>[pickup, destination];
              if (animatedPos != null) cameraPoints.add(animatedPos);
              _lastCameraPoints = cameraPoints;

              final markers = _buildMarkers(
                pickup: pickup,
                destination: destination,
              );
              final polylines = _routePoints.length >= 2
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _routePoints,
                        color: AppBrandAssets.brandTealDark,
                        width: 5,
                      ),
                    }
                  : <Polyline>{};

              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        GoogleMapView(
                          initialPosition: animatedPos ?? pickup,
                          zoom: 14,
                          markers: markers,
                          polylines: polylines,
                          onCameraMove: (_) =>
                              _cameraFollow.onUserCameraInteraction(),
                          onMapCreated: (c) {
                            _mapController = c;
                            if (!_didInitialCameraFit) {
                              _didInitialCameraFit = true;
                              unawaited(_recenterCamera(cameraPoints));
                            }
                          },
                        ),
                        Positioned(
                          right: AppSpacing.lg,
                          bottom: AppSpacing.lg,
                          child: Material(
                            color: Colors.white,
                            elevation: 4,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => unawaited(
                                _recenterCamera(_lastCameraPoints),
                              ),
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
                        if (driverPos == null)
                          Positioned(
                            top: AppSpacing.md,
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            child: AppBanner(
                              message: l10n.noLocationYet,
                              icon: Icons.location_searching,
                              tone: AppBannerTone.info,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadii.xl),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppSheetHandle(),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                ProfileAvatarCircle.driver(
                                  driverId: driverId,
                                  name: driver?.name ?? '',
                                  profilePhotoUrl:
                                      driver?.profilePhotoUrl ?? '',
                                  radius: 28,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _statusText(l10n, ride.status),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: AppBrandAssets.brandNavy,
                                            ),
                                      ),
                                      Text(
                                        driver?.name ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        '${isArabic ? 'توك توك' : 'Tuk-Tuk'}'
                                        '${(driver?.vehiclePlate ?? '').isNotEmpty ? ' • ${driver!.vehiclePlate}' : ''}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppBrandAssets.brandMuted,
                                            ),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 16,
                                            color: AppBrandAssets.brandGold,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            (driver?.rating ?? 5)
                                                .toStringAsFixed(1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_etaMinutes != null || _distanceKm != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  if (_etaMinutes != null)
                                    Expanded(
                                      child: AppStatCard(
                                        label: l10n.minutes,
                                        value: '$_etaMinutes',
                                        icon: Icons.schedule,
                                      ),
                                    ),
                                  if (_etaMinutes != null &&
                                      _distanceKm != null)
                                    const SizedBox(width: AppSpacing.md),
                                  if (_distanceKm != null)
                                    Expanded(
                                      child: AppStatCard(
                                        label: isArabic ? 'كم' : 'km',
                                        value:
                                            _distanceKm!.toStringAsFixed(1),
                                        icon: Icons.route,
                                        accent: AppBrandAssets.brandGold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            AppBanner(
                              message:
                                  '${l10n.cashFare}: ${_fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)} • ${l10n.paymentMethodCash}',
                              icon: Icons.payments_outlined,
                              tone: AppBannerTone.info,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: AppSecondaryButton(
                                    label: isArabic ? 'اتصال' : 'Call',
                                    icon: Icons.phone,
                                    onPressed: () =>
                                        _callDriver(driver?.phone),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: AppSecondaryButton(
                                    label: l10n.openChat,
                                    icon: Icons.chat_bubble_outline,
                                    onPressed: currentUser == null
                                        ? null
                                        : () async {
                                            final profile = await authService
                                                .watchCurrentProfile()
                                                .first;
                                            if (!context.mounted) return;
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => RideChatScreen(
                                                  rideId: widget.rideId,
                                                  currentUserId:
                                                      currentUser.uid,
                                                  currentUserRole:
                                                      UserRole.customer,
                                                  currentUserName:
                                                      profile?.name ??
                                                          l10n.roleCustomer,
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                                ),
                              ],
                            ),
                            if (customerCanCancelRide(ride.status)) ...[
                              const SizedBox(height: AppSpacing.sm),
                              AppSecondaryButton(
                                label: l10n.cancel,
                                destructive: true,
                                onPressed: () => cancelCustomerRideAndExit(
                                  context,
                                  widget.rideId,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _statusText(AppLocalizations l10n, RideStatus status) {
    return switch (status) {
      RideStatus.accepted => l10n.driverFound,
      RideStatus.inProgress => l10n.tripInProgress,
      _ => l10n.driverFound,
    };
  }
}

/// Tiny haversine helper to avoid importing geolocator into UI for one calc.
class GeolocatorLite {
  static double distanceMeters(LatLng a, LatLng b) {
    return NearbyProvidersService.straightLineKm(
          ll.LatLng(a.latitude, a.longitude),
          ll.LatLng(b.latitude, b.longitude),
        ) *
        1000;
  }
}
