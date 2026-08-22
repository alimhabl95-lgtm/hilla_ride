import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Toolbar button that returns the user to their active ride screen.
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

        return IconButton(
          tooltip: l10n.currentRideTitle,
          onPressed: !hasRide
              ? null
              : () {
                  // Pop overlays (chat/profile/search) back to the shell that
                  // hosts the live ride UI.
                  final navigator = Navigator.of(context);
                  navigator.popUntil((route) => route.isFirst);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.localeName.startsWith('ar')
                            ? 'تم فتح المشوار الحالي'
                            : 'Opened your current ride',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
          icon: Badge(
            isLabelVisible: hasRide,
            smallSize: 10,
            child: Icon(
              Icons.local_taxi_outlined,
              color: hasRide
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).disabledColor,
            ),
          ),
        );
      },
    );
  }
}
