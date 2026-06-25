import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/map_camera_helper.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/features/customer/customer_ride_actions.dart';
import 'package:hilla_ride/features/customer/screens/trip_completed_screen.dart';
import 'package:hilla_ride/features/shared/screens/ride_chat_screen.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

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
  var _markersReady = false;
  String? _lastCameraKey;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;
  String? _loadedMarkerKey;

  @override
  void initState() {
    super.initState();
    MapMarkerIcons.ensureLoaded().then((_) {
      if (mounted) setState(() => _markersReady = true);
    });
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

  void _updateCamera(Iterable<LatLng> points) {
    final controller = _mapController;
    if (controller == null) return;

    final key = points
        .map((point) =>
            '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}')
        .join('|');
    if (key == _lastCameraKey) return;
    _lastCameraKey = key;

    unawaited(MapCameraHelper.fitPoints(controller, points));
  }

  Set<Marker> _buildMarkers({
    required LatLng pickup,
    required LatLng destination,
    LatLng? driverPos,
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

    if (driverPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon: MapMarkerIcons.driver!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    final driverService = context.read<AppState>().driverService;
    final authService = context.read<AppState>().authService;
    final currentUser = authService.currentUser;

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
              final destination = LatLng(ride.destinationLat, ride.destinationLng);
              LatLng? driverPos;
              if (driver?.latitude != null && driver?.longitude != null) {
                driverPos = LatLng(driver!.latitude!, driver.longitude!);
              }

              unawaited(_loadTripMarkers(
                pickupLabel: ride.pickupLabel,
                destinationLabel: ride.destinationLabel,
              ));

              final cameraPoints = <LatLng>[pickup, destination];
              if (driverPos != null) cameraPoints.add(driverPos);
              _updateCamera(cameraPoints);

              final markers = _buildMarkers(
                pickup: pickup,
                destination: destination,
                driverPos: driverPos,
              );

              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        GoogleMapView(
                          initialPosition: driverPos ?? pickup,
                          zoom: 14,
                          markers: markers,
                          onMapCreated: (c) {
                            _mapController = c;
                            _lastCameraKey = null;
                            _updateCamera(cameraPoints);
                          },
                        ),
                        if (driverPos == null)
                          Positioned(
                            top: 12,
                            left: 12,
                            right: 12,
                            child: Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l10n.noLocationYet,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Material(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ProfileAvatarCircle.driver(
                                driverId: driverId,
                                name: driver?.name ?? '',
                                profilePhotoUrl: driver?.profilePhotoUrl ?? '',
                                radius: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _statusText(l10n, ride.status),
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      '${driver?.name ?? ''} • ${driver?.vehiclePlate ?? ''}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.cashFare}: ${_fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}',
                          ),
                          Text(l10n.paymentMethodCash),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
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
                                          currentUserId: currentUser.uid,
                                          currentUserRole: UserRole.customer,
                                          currentUserName:
                                              profile?.name ?? l10n.roleCustomer,
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: Text(l10n.openChat),
                          ),
                          if (customerCanCancelRide(ride.status)) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () => cancelCustomerRideAndExit(
                                context,
                                widget.rideId,
                              ),
                              child: Text(l10n.cancel),
                            ),
                          ],
                        ],
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
