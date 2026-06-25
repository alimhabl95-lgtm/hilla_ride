import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/customer/screens/customer_home_map_screen.dart';
import 'package:hilla_ride/features/customer/screens/driver_assigned_screen.dart';
import 'package:hilla_ride/features/customer/screens/finding_driver_screen.dart';
import 'package:hilla_ride/features/customer/screens/track_driver_screen.dart';
import 'package:hilla_ride/features/customer/screens/trip_completed_screen.dart';
import 'package:provider/provider.dart';

/// Restores the customer's in-progress trip after refresh or re-login.
class CustomerActiveRideShell extends StatelessWidget {
  const CustomerActiveRideShell({
    super.key,
    required this.user,
    required this.rideId,
  });

  final AppUser user;
  final String rideId;

  @override
  Widget build(BuildContext context) {
    final rideService = context.read<AppState>().rideService;

    return StreamBuilder<Ride?>(
      stream: rideService.watchRide(rideId),
      builder: (context, snapshot) {
        final ride = snapshot.data;
        if (ride == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return CustomerHomeMapScreen(user: user);
        }

        if (ride.status == RideStatus.cancelled) {
          return CustomerHomeMapScreen(user: user);
        }

        switch (ride.status) {
          case RideStatus.searching:
            return FindingDriverScreen(rideId: rideId, embedded: true);
          case RideStatus.matched:
            return DriverAssignedScreen(rideId: rideId, embedded: true);
          case RideStatus.accepted:
          case RideStatus.inProgress:
          case RideStatus.awaitingCashPayment:
            return TrackDriverScreen(rideId: rideId, embedded: true);
          case RideStatus.completed:
            return TripCompletedScreen(rideId: rideId);
          case RideStatus.cancelled:
            return CustomerHomeMapScreen(user: user);
        }
      },
    );
  }
}
