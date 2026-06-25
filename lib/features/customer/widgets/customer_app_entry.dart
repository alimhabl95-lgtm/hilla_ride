import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/customer/screens/customer_home_map_screen.dart';
import 'package:hilla_ride/features/customer/widgets/customer_active_ride_shell.dart';
import 'package:provider/provider.dart';

class CustomerAppEntry extends StatefulWidget {
  const CustomerAppEntry({super.key, required this.user});

  final AppUser user;

  @override
  State<CustomerAppEntry> createState() => _CustomerAppEntryState();
}

class _CustomerAppEntryState extends State<CustomerAppEntry> {
  Ride? _fallbackRide;
  var _fallbackChecked = false;

  Future<void> _loadFallbackRide() async {
    if (_fallbackChecked) return;
    _fallbackChecked = true;
    try {
      final ride = await context
          .read<AppState>()
          .rideService
          .fetchActiveRideForCustomer(widget.user.uid);
      if (!mounted) return;
      setState(() => _fallbackRide = ride);
    } catch (_) {
      if (mounted) setState(() => _fallbackRide = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideService = context.read<AppState>().rideService;

    return StreamBuilder<Ride?>(
      stream: rideService.watchActiveRideForCustomer(widget.user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError && !_fallbackChecked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadFallbackRide();
          });
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !_fallbackChecked) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final activeRide = snapshot.data ?? _fallbackRide;
        if (activeRide != null) {
          return CustomerActiveRideShell(
            user: widget.user,
            rideId: activeRide.id,
          );
        }

        return CustomerHomeMapScreen(user: widget.user);
      },
    );
  }
}
