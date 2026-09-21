import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/customer_location_publisher.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/customer/screens/customer_home_map_screen.dart';
import 'package:hilla_ride/features/customer/screens/driver_assigned_screen.dart';
import 'package:hilla_ride/features/customer/screens/finding_driver_screen.dart';
import 'package:hilla_ride/features/customer/screens/track_driver_screen.dart';
import 'package:hilla_ride/features/customer/screens/trip_completed_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Restores the customer's in-progress trip after refresh or re-login.
class CustomerActiveRideShell extends StatefulWidget {
  const CustomerActiveRideShell({
    super.key,
    required this.user,
    required this.rideId,
    this.onMinimize,
  });

  final AppUser user;
  final String rideId;
  final VoidCallback? onMinimize;

  @override
  State<CustomerActiveRideShell> createState() =>
      _CustomerActiveRideShellState();
}

class _CustomerActiveRideShellState extends State<CustomerActiveRideShell> {
  final _locationPublisher = CustomerLocationPublisher();

  @override
  void initState() {
    super.initState();
    unawaited(_locationPublisher.start(widget.user.uid));
  }

  @override
  void dispose() {
    unawaited(_locationPublisher.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideService = context.read<AppState>().rideService;

    return StreamBuilder<Ride?>(
      stream: rideService.watchRide(widget.rideId),
      builder: (context, snapshot) {
        final ride = snapshot.data;
        if (ride == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: AppLoadingState(),
            );
          }
          return CustomerHomeMapScreen(user: widget.user);
        }

        if (ride.status == RideStatus.cancelled) {
          return CustomerHomeMapScreen(user: widget.user);
        }

        switch (ride.status) {
          case RideStatus.searching:
            return _wrapSession(
              FindingDriverScreen(rideId: widget.rideId, embedded: true),
            );
          case RideStatus.matched:
            return _wrapSession(
              DriverAssignedScreen(rideId: widget.rideId, embedded: true),
            );
          case RideStatus.accepted:
          case RideStatus.inProgress:
          case RideStatus.awaitingCashPayment:
            return _wrapSession(
              TrackDriverScreen(rideId: widget.rideId, embedded: true),
            );
          case RideStatus.completed:
            return TripCompletedScreen(rideId: widget.rideId);
          case RideStatus.cancelled:
            return CustomerHomeMapScreen(user: widget.user);
        }
      },
    );
  }

  Widget _wrapSession(Widget child) {
    final onMinimize = widget.onMinimize;
    if (onMinimize == null) return child;

    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          elevation: 1,
          child: SafeArea(
            bottom: false,
            child: IconButton(
              alignment: Alignment.centerLeft,
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.currentRideTitle,
              onPressed: onMinimize,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
