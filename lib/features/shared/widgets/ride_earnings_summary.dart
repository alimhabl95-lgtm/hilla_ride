import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

class RideEarningsSummary extends StatelessWidget {
  const RideEarningsSummary({
    super.key,
    required this.ride,
    this.showDriverNet = false,
  });

  final Ride ride;
  final bool showDriverNet;

  @override
  Widget build(BuildContext context) {
    if (ride.status != RideStatus.completed || ride.fareAmountIqd <= 0) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final locale = l10n.localeName;
    final percent = ride.commissionPercent;

    return Text(
      showDriverNet
          ? l10n.rideEarningsDriver(
              fareService.formatIqd(ride.driverEarningsIqd, locale: locale),
              fareService.formatIqd(ride.platformCommissionIqd, locale: locale),
              percent == null ? '—' : percent.toStringAsFixed(1),
            )
          : l10n.rideEarningsManager(
              fareService.formatIqd(ride.fareAmountIqd, locale: locale),
              fareService.formatIqd(ride.platformCommissionIqd, locale: locale),
              percent == null ? '—' : percent.toStringAsFixed(1),
            ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
