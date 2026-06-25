import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/app_map.dart';
import 'package:hilla_ride/features/customer/customer_ride_actions.dart';
import 'package:hilla_ride/features/customer/screens/trip_completed_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class ActiveRideScreen extends StatefulWidget {
  const ActiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _mapController = MapController();
  static const _fareService = FareService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    final driverService = context.read<AppState>().driverService;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveDriverLocation)),
      body: StreamBuilder<Ride?>(
        stream: rideService.watchRide(widget.rideId),
        builder: (context, rideSnapshot) {
          final ride = rideSnapshot.data;
          if (ride == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ride.status == RideStatus.completed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => TripCompletedScreen(rideId: widget.rideId),
                ),
              );
            });
            return Center(child: Text(l10n.rideCompleted));
          }

          final driverId = ride.driverId;
          if (driverId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.searchingDriver),
                    const SizedBox(height: 24),
                    if (customerCanCancelRide(ride.status))
                      OutlinedButton(
                        onPressed: () =>
                            cancelCustomerRideAndExit(context, widget.rideId),
                        child: Text(l10n.cancel),
                      ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<DriverProfile?>(
            stream: driverService.watchDriverLocation(driverId),
            builder: (context, driverSnapshot) {
              final driver = driverSnapshot.data;
              final markers = <Marker>[
                Marker(
                  point: LatLng(ride.pickupLat, ride.pickupLng),
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.trip_origin, color: Color(0xFF0F766E)),
                ),
                Marker(
                  point: LatLng(ride.destinationLat, ride.destinationLng),
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_on, color: Colors.red),
                ),
              ];

              var mapCenter = LatLng(ride.pickupLat, ride.pickupLng);
              if (driver?.latitude != null && driver?.longitude != null) {
                final driverPoint = LatLng(driver!.latitude!, driver.longitude!);
                mapCenter = driverPoint;
                markers.add(
                  Marker(
                    point: driverPoint,
                    width: 48,
                    height: 48,
                    child: const Icon(Icons.local_taxi, color: Colors.black, size: 36),
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: AppMap(
                      mapController: _mapController,
                      center: mapCenter,
                      zoom: HillaConstants.userLocationZoom,
                      markers: markers,
                      onMapReady: () {
                        _mapController.move(mapCenter, HillaConstants.userLocationZoom);
                      },
                    ),
                  ),
                  Material(
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _statusLabel(l10n, ride.status),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${l10n.rideFrom}: ${ride.pickupLabel}'),
                          Text('${l10n.rideTo}: ${ride.destinationLabel}'),
                          Text(
                            '${l10n.cashFare}: ${_fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}',
                          ),
                          Text(l10n.paymentMethodCash),
                          if (driver != null) ...[
                            const SizedBox(height: 8),
                            Text('${driver.name} • ${driver.vehiclePlate}'),
                          ],
                          const SizedBox(height: 12),
                          if (customerCanCancelRide(ride.status))
                            OutlinedButton(
                              onPressed: () => cancelCustomerRideAndExit(
                                context,
                                widget.rideId,
                              ),
                              child: Text(l10n.cancel),
                            ),
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

  String _statusLabel(AppLocalizations l10n, RideStatus status) {
    return switch (status) {
      RideStatus.matched => l10n.searchingDriver,
      RideStatus.accepted || RideStatus.inProgress => l10n.driverFound,
      RideStatus.awaitingCashPayment => l10n.awaitingPayment,
      RideStatus.completed => l10n.rideCompleted,
      _ => l10n.searchingDriver,
    };
  }
}
