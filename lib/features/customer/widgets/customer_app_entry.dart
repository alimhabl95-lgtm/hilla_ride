import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/customer/customer_ride_navigation.dart';
import 'package:hilla_ride/features/customer/widgets/customer_active_ride_shell.dart';
import 'package:hilla_ride/features/customer/widgets/customer_home_shell.dart';
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
  String? _sessionRideId;
  String? _minimizedRideId;

  @override
  void initState() {
    super.initState();
    CustomerRideNavigation.openActiveRideSession = (rideId) {
      if (!mounted) return;
      setState(() {
        _sessionRideId = rideId;
        _minimizedRideId = null;
      });
    };
    CustomerRideNavigation.minimizeActiveRideSession = () {
      if (!mounted) return;
      setState(() {
        _minimizedRideId = _sessionRideId;
        _sessionRideId = null;
      });
    };
  }

  @override
  void dispose() {
    if (CustomerRideNavigation.openActiveRideSession != null) {
      CustomerRideNavigation.openActiveRideSession = null;
    }
    if (CustomerRideNavigation.minimizeActiveRideSession != null) {
      CustomerRideNavigation.minimizeActiveRideSession = null;
    }
    super.dispose();
  }

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

  void _syncSessionWithActiveRide(Ride? activeRide) {
    if (activeRide == null) {
      if (_sessionRideId != null || _minimizedRideId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _sessionRideId = null;
            _minimizedRideId = null;
          });
        });
      }
      return;
    }
    if (_sessionRideId == activeRide.id) return;
    if (_minimizedRideId == activeRide.id) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _sessionRideId = activeRide.id;
        _minimizedRideId = null;
      });
    });
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
        _syncSessionWithActiveRide(activeRide);

        final inActiveSession = activeRide != null &&
            _sessionRideId != null &&
            _sessionRideId == activeRide.id;

        if (inActiveSession) {
          return CustomerActiveRideShell(
            user: widget.user,
            rideId: activeRide.id,
            onMinimize: CustomerRideNavigation.minimizeSession,
          );
        }

        return CustomerHomeShell(
          user: widget.user,
          activeRideId: activeRide?.id,
          onOpenCurrentRide: activeRide == null
              ? null
              : () => CustomerRideNavigation.openSession(activeRide.id),
        );
      },
    );
  }
}
