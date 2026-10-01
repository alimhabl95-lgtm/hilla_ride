import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
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
        if (ride == null) {
          return const SizedBox.shrink();
        }

        return TextButton.icon(
          onPressed: () => _openCurrentRide(context, role, ride.id),
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

/// Compact taxi control for the map floating chrome (42×42 circle).
class CurrentRideFloatingButton extends StatelessWidget {
  const CurrentRideFloatingButton({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = context.read<AppState>().authService.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final rideService = context.read<AppState>().rideService;
    final stream = role == UserRole.driver
        ? rideService.watchAssignedRideForDriver(uid)
        : rideService.watchActiveRideForCustomer(uid);

    return StreamBuilder<Ride?>(
      stream: stream,
      builder: (context, snapshot) {
        final ride = snapshot.data;
        if (ride == null) return const SizedBox.shrink();

        return IconButton(
          tooltip: l10n.currentRideTitle,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () => _openCurrentRide(context, role, ride.id),
          icon: Badge(
            isLabelVisible: true,
            smallSize: 8,
            child: const Icon(
              Icons.local_taxi,
              color: AppBrandAssets.brandTealDark,
            ),
          ),
        );
      },
    );
  }
}

/// Top entry in the customer overflow menu when a trip is active.
class CustomerCurrentRideMenuTile extends StatelessWidget {
  const CustomerCurrentRideMenuTile({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;

    return StreamBuilder<Ride?>(
      stream: rideService.watchActiveRideForCustomer(customerId),
      builder: (context, snapshot) {
        final ride = snapshot.data;
        if (ride == null) return const SizedBox.shrink();

        return Material(
          color: AppBrandAssets.brandTealDark.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: const Icon(
              Icons.local_taxi,
              color: AppBrandAssets.brandTealDark,
            ),
            title: Text(
              l10n.currentRideTitle,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppBrandAssets.brandTealDark,
              ),
            ),
            subtitle: Text(
              l10n.localeName.startsWith('ar')
                  ? 'عرض السائق والمسار وحالة الرحلة'
                  : 'View driver, route, and trip status',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppBrandAssets.brandTealDark,
            ),
            onTap: () => CustomerRideNavigation.openSession(ride.id),
          ),
        );
      },
    );
  }
}

void _openCurrentRide(BuildContext context, UserRole role, String rideId) {
  if (role == UserRole.customer) {
    CustomerRideNavigation.openSession(rideId);
  } else {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
