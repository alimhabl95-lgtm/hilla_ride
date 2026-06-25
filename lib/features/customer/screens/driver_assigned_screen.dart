import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/features/customer/customer_ride_actions.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DriverAssignedScreen extends StatefulWidget {
  const DriverAssignedScreen({
    super.key,
    required this.rideId,
    this.embedded = false,
  });

  final String rideId;
  final bool embedded;

  @override
  State<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends State<DriverAssignedScreen> {
  var _notifiedAccepted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    final driverService = context.read<AppState>().driverService;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverAssignedTitle)),
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

          if (ride.status == RideStatus.accepted && !_notifiedAccepted) {
            _notifiedAccepted = true;
            NotificationService.notifyCustomerRideAccepted(ride);
          }

          final driverId = ride.driverId;
          if (driverId == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    ride.status == RideStatus.matched
                        ? l10n.waitingDriverAccept
                        : l10n.searchingDriver,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (customerCanCancelRide(ride.status)) ...[
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () =>
                          cancelCustomerRideAndExit(context, widget.rideId),
                      child: Text(l10n.cancel),
                    ),
                  ],
                ],
              ),
            );
          }

          return StreamBuilder<DriverProfile?>(
            stream: driverService.watchDriver(driverId),
            builder: (context, driverSnapshot) {
              final driver = driverSnapshot.data;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ProfileAvatarCircle.driver(
                      driverId: driverId,
                      name: driver?.name ?? '',
                      profilePhotoUrl: driver?.profilePhotoUrl ?? '',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      driver?.name ?? l10n.searchingDriver,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final rating = driver?.rating ?? 5.0;
                        return Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.directions_car),
                              title: Text(driver?.vehicleType ?? '—'),
                              subtitle: Text(driver?.vehicleColor ?? ''),
                            ),
                            ListTile(
                              leading: const Icon(Icons.pin),
                              title: Text(l10n.vehiclePlate),
                              subtitle: Text(
                                driver?.vehiclePlate ?? '—',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (ride.status == RideStatus.matched)
                      Text(l10n.waitingDriverAccept, textAlign: TextAlign.center),
                    if (customerCanCancelRide(ride.status)) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () =>
                            cancelCustomerRideAndExit(context, widget.rideId),
                        child: Text(l10n.cancel),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
