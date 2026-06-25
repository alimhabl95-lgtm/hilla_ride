import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/widgets/admin_customers_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_district_panel.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:hilla_ride/features/shared/widgets/ride_earnings_summary.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminDriverDetailScreen extends StatefulWidget {
  const AdminDriverDetailScreen({super.key, required this.driver});

  final DriverProfile driver;

  @override
  State<AdminDriverDetailScreen> createState() =>
      _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends State<AdminDriverDetailScreen> {
  var _isReceivingProfits = false;

  Future<void> _markProfitsReceived(DriverProfile driver) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AppState>().authService.currentUser;
    if (auth == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.receivedProfitsTitle),
        content: Text(
          l10n.receivedProfitsConfirm(
            FareService().formatIqd(
              driver.owedPlatformCommissionIqd,
              locale: l10n.localeName,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.receivedProfitsAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isReceivingProfits = true);
    try {
      await context.read<AppState>().adminService.markProfitsReceived(
            driverId: driver.uid,
            receivedByUid: auth.uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.receivedProfitsSuccess)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isReceivingProfits = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    const fareService = FareService();
    final driverService = context.read<AppState>().driverService;

    return FutureBuilder<AppUser?>(
      future: adminService.getUser(widget.driver.uid),
      builder: (context, userSnapshot) {
        return StreamBuilder<DriverProfile?>(
          stream: adminService.watchDriver(widget.driver.uid),
          builder: (context, driverSnapshot) {
            final driver = driverSnapshot.data ?? widget.driver;
            final user = userSnapshot.data;
            final displayPhone = driver.phone.trim().isNotEmpty
                ? driver.phone.trim()
                : (user?.phone.trim() ?? '');
            final lastReceived = driver.lastProfitReceivedAt;

            return Scaffold(
              appBar: AppBar(
                title: Text('${l10n.driverHistoryTitle}: ${driver.name}'),
                actions: [
                  TextButton(
                    onPressed: () => driverService.setDriverBlocked(
                      driverId: driver.uid,
                      blocked: !driver.isBlocked,
                    ),
                    child: Text(
                      driver.isBlocked ? l10n.unblockUser : l10n.blockUser,
                    ),
                  ),
                ],
              ),
              body: StreamBuilder<List<Ride>>(
                stream: adminService.watchRidesForDriver(driver.uid),
                builder: (context, rideSnapshot) {
                  final rides = rideSnapshot.data ?? const [];

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone_outlined,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        displayPhone.isNotEmpty
                                            ? '${l10n.phoneHint}: $displayPhone'
                                            : '${l10n.phoneHint}: —',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${driver.vehiclePlate.isEmpty ? '—' : driver.vehiclePlate} • ${driver.vehicleType.isEmpty ? '—' : driver.vehicleType}',
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${l10n.completedRidesCount}: ${driver.completedRidesCount}',
                                  ),
                                  Text(
                                    '${l10n.outstandingProfitLabel}: ${fareService.formatIqd(driver.owedPlatformCommissionIqd, locale: l10n.localeName)}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${l10n.lifetimeProfitLabel}: ${fareService.formatIqd(driver.totalPlatformCommissionIqd, locale: l10n.localeName)}',
                                  ),
                                  Text(
                                    '${l10n.driverNetEarnings}: ${fareService.formatIqd(driver.totalDriverEarningsIqd, locale: l10n.localeName)}',
                                  ),
                                  if (driver.pendingBonusIqd > 0)
                                    Text(
                                      '${l10n.pendingBonusLabel}: ${fareService.formatIqd(driver.pendingBonusIqd, locale: l10n.localeName)}',
                                    ),
                                  if (lastReceived != null)
                                    Text(
                                      '${l10n.lastProfitReceivedLabel}: ${DateFormat.yMMMd(l10n.localeName).add_jm().format(lastReceived)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  Text(
                                    '${l10n.cancelledRidesCount}: ${driver.cancelledRidesCount}',
                                  ),
                                  if (driver.isBlocked)
                                    Text(
                                      l10n.blockedLabel,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  if (driver.owedPlatformCommissionIqd > 0)
                                    FilledButton.icon(
                                      onPressed: _isReceivingProfits
                                          ? null
                                          : () => _markProfitsReceived(driver),
                                      icon: _isReceivingProfits
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.check_circle),
                                      label: Text(l10n.receivedProfitsAction),
                                    ),
                                  const SizedBox(height: 12),
                                  AdminDriverDistrictPanel(driver: driver),
                                  const SizedBox(height: 12),
                                  DriverDocumentPhotos(driver: driver),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            l10n.rideHistoryTab,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      if (rides.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text(l10n.noRideHistory)),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList.separated(
                            itemCount: rides.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final ride = rides[index];
                              final date = ride.createdAt;
                              final dateLabel = date == null
                                  ? ''
                                  : DateFormat.yMMMd(l10n.localeName)
                                      .add_jm()
                                      .format(date);

                              return Card(
                                child: ListTile(
                                  title: Text(
                                    '${ride.pickupLabel} → ${ride.destinationLabel}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${ride.status.name} • ${fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}${dateLabel.isEmpty ? '' : '\n$dateLabel'}',
                                      ),
                                      RideEarningsSummary(ride: ride),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
