import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

Future<void> cancelCustomerRideAndExit(
  BuildContext context,
  String rideId,
) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    await context.read<AppState>().rideService.cancelRide(rideId);
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bookRideFailed)),
    );
  }
}

bool customerCanCancelRide(RideStatus status) {
  return status != RideStatus.inProgress &&
      status != RideStatus.awaitingCashPayment &&
      status != RideStatus.completed &&
      status != RideStatus.cancelled;
}
