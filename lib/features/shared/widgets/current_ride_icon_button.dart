import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/customer/customer_ride_navigation.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Toolbar control to reopen the active ride UI (hidden when no active ride).
class CurrentRideIconButton extends StatelessWidget {
  const CurrentRideIconButton({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.read<AppState>().authService;
    final rideService = context.read<AppState>().rideService;
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    final stream = role == UserRole.driver
        ? rideService.watchAssignedRideForDriver(uid)
        : rideService.watchActiveRideForCustomer(uid);

    return StreamBuilder<Ride?>(
      stream: stream,
      builder: (context, snapshot) {
        final ride = snapshot.data;
        final hasRide = ride != null;
        if (!hasRide) {
          return const SizedBox.shrink();
        }

        return TextButton.icon(
          onPressed: () {
            if (role == UserRole.customer) {
              CustomerRideNavigation.openSession(ride.id);
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          icon: Badge(
            isLabelVisible: true,
            smallSize: 8,
            child: Icon(
              Icons.local_taxi_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          label: Text(
            l10n.currentRideTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}
