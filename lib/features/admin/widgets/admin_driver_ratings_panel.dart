import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminDriverRatingsPanel extends StatelessWidget {
  const AdminDriverRatingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;

    return StreamBuilder<List<Ride>>(
      stream: adminService.watchDriverReviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rides = snapshot.data ?? const [];
        if (rides.isEmpty) {
          return Center(child: Text(l10n.noDriverReviews));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _DriverReviewCard(ride: rides[index]),
        );
      },
    );
  }
}

class _DriverReviewCard extends StatelessWidget {
  const _DriverReviewCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    final dateFormat = DateFormat.yMMMd(l10n.localeName).add_Hm();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...List.generate(
                  5,
                  (index) => Icon(
                    index < (ride.driverRating ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${ride.driverRating}/5',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<DriverProfile?>(
              future: ride.driverId == null
                  ? Future.value(null)
                  : adminService.getDriver(ride.driverId!),
              builder: (context, driverSnapshot) {
                final driver = driverSnapshot.data;
                final driverName = driver?.name;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.driverLabel}: ${driverName?.isNotEmpty == true ? driverName : l10n.unknownUser}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (driver != null)
                      Text(
                        '${l10n.phoneHint}: ${driver.phone.isNotEmpty ? driver.phone : '—'}',
                      ),
                  ],
                );
              },
            ),
            FutureBuilder<AppUser?>(
              future: adminService.getUser(ride.customerId),
              builder: (context, customerSnapshot) {
                final customerName = customerSnapshot.data?.name;
                return Text(
                  '${l10n.customerLabel}: ${customerName?.isNotEmpty == true ? customerName : l10n.unknownUser}',
                );
              },
            ),
            if (ride.pickupLabel.isNotEmpty || ride.destinationLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${ride.pickupLabel} → ${ride.destinationLabel}'),
              ),
            if (ride.driverFeedback != null &&
                ride.driverFeedback!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.feedbackLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(ride.driverFeedback!),
            ],
            if (ride.ratedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                dateFormat.format(ride.ratedAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
