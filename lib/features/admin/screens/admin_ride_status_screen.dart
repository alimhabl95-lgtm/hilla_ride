import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/screens/admin_ride_detail_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminRideStatusScreen extends StatelessWidget {
  const AdminRideStatusScreen({
    super.key,
    required this.status,
    required this.title,
  });

  final RideStatus status;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    const fareService = FareService();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<List<Ride>>(
        stream: adminService.watchRidesByStatus(status),
        builder: (context, snapshot) {
          final rides = snapshot.data ?? const [];

          if (rides.isEmpty) {
            return Center(child: Text(l10n.noRideHistory));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ride = rides[index];
              final when = ride.completedAt ?? ride.createdAt;
              final dateLabel = when == null
                  ? '—'
                  : DateFormat.yMMMd(l10n.localeName).add_jm().format(when);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('${ride.pickupLabel} → ${ride.destinationLabel}'),
                  subtitle: Text(
                    '${l10n.tripDateTime}: $dateLabel\n'
                    '${l10n.statusLabel}: ${ride.status.name} • '
                    '${fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminRideDetailScreen(ride: ride),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
