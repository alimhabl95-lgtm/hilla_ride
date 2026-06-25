import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/features/driver/widgets/driver_ride_map_panel.dart';
import 'package:hilla_ride/features/shared/screens/ride_chat_screen.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/features/shared/widgets/ride_earnings_summary.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.driver,
  });

  final DriverProfile driver;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isUpdatingOnline = false;
  final _pendingRideActions = <String>{};

  String _actionKey(String rideId, String action) => '$rideId:$action';

  bool _isActionPending(String rideId, String action) =>
      _pendingRideActions.contains(_actionKey(rideId, action));

  Future<void> _runRideAction({
    required String rideId,
    required String action,
    required Future<void> Function() task,
  }) async {
    final key = _actionKey(rideId, action);
    if (_pendingRideActions.contains(key)) return;
    setState(() => _pendingRideActions.add(key));
    try {
      await task();
    } finally {
      if (mounted) setState(() => _pendingRideActions.remove(key));
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.driver.isOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(NotificationService.unlockAudioIfNeeded());
        context
            .read<AppState>()
            .driverService
            .refreshOnlineMatchingProfile(widget.driver.uid);
      });
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _isUpdatingOnline = true);
    try {
      if (value) {
        unawaited(NotificationService.unlockAudioIfNeeded());
      }
      await context.read<AppState>().driverService.setOnlineStatus(
            driverId: widget.driver.uid,
            isOnline: value,
          );
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final message = error is StateError && error.message == 'work_area_required'
          ? l10n.driverWorkDistrictRequired
          : l10n.accountBlockedTitle;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingOnline = false);
    }
  }

  Future<void> _confirmCashCollected(Ride ride) async {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    try {
      await rideService.confirmCashCollected(ride.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rideCompleted)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Widget _actionButton({
    required String rideId,
    required String action,
    required String label,
    required Future<void> Function() onPressed,
  }) {
    final pending = _isActionPending(rideId, action);
    return FilledButton(
      onPressed: pending
          ? null
          : () => _runRideAction(
                rideId: rideId,
                action: action,
                task: onPressed,
              ),
      child: pending
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    const fareService = FareService();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roleDriver),
        actions: [
          Switch(
            value: widget.driver.isOnline,
            onChanged: _isUpdatingOnline || !widget.driver.hasAssignedWorkArea
                ? null
                : _toggleOnline,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Center(
              child: Text(widget.driver.isOnline ? l10n.goOnline : l10n.goOffline),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DriverProfile?>(
        stream: context.read<AppState>().driverService.watchDriver(widget.driver.uid),
        builder: (context, driverSnapshot) {
          final driver = driverSnapshot.data ?? widget.driver;

          return StreamBuilder<Ride?>(
            stream: rideService.watchAssignedRideForDriver(driver.uid),
            builder: (context, snapshot) {
              final ride = snapshot.data;
              final activeRide = ride != null &&
                      ride.status != RideStatus.cancelled &&
                      ride.status != RideStatus.completed
                  ? ride
                  : null;

              return Column(
                children: [
                  if (!driver.hasAssignedWorkArea)
                    MaterialBanner(
                      content: Text(l10n.driverWorkDistrictRequired),
                      leading: const Icon(Icons.location_city_outlined),
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      actions: const [SizedBox.shrink()],
                    ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (activeRide == null) {
                          return ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              StreamBuilder<DriverMonthlyStats>(
                                stream: context
                                    .read<AppState>()
                                    .monthlyPrizeService
                                    .watchDriverStats(driver.uid),
                                builder: (context, statsSnapshot) {
                                  final stats = statsSnapshot.data;
                                  if (stats == null) {
                                    return const SizedBox.shrink();
                                  }

                                  return Card(
                                    color: const Color(0xFF0F766E)
                                        .withValues(alpha: 0.08),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.emoji_events_outlined,
                                                color: Color(0xFFD97706),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  l10n.driverMonthlyPrizeTitle,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            l10n.driverMonthlyRideCount(
                                              stats.rideCount,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.driverMonthlyRank(
                                              stats.rank,
                                              stats.rideCount,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.driverMonthlyPrizeAmount(
                                              fareService.formatIqd(
                                                stats.prizeAmountIqd,
                                                locale: l10n.localeName,
                                              ),
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      const Color(0xFFD97706),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.yourEarningsTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${l10n.completedRidesCount}: ${driver.completedRidesCount}',
                                      ),
                                      Text(
                                        '${l10n.driverNetEarnings}: ${fareService.formatIqd(driver.totalDriverEarningsIqd, locale: l10n.localeName)}',
                                      ),
                                      Text(
                                        '${l10n.owedToPlatformLabel}: ${fareService.formatIqd(driver.owedPlatformCommissionIqd, locale: l10n.localeName)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      if (driver.pendingBonusIqd > 0)
                                        Text(
                                          '${l10n.pendingBonusLabel}: ${fareService.formatIqd(driver.pendingBonusIqd, locale: l10n.localeName)}',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: Text(
                                  driver.isOnline
                                      ? l10n.waitingForRides
                                      : l10n.goOnline,
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DriverRideMapPanel(
                                ride: activeRide,
                                driver: driver,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          StreamBuilder<AppUser?>(
                                            stream: context
                                                .read<AppState>()
                                                .authService
                                                .watchUser(activeRide.customerId),
                                            builder: (context, customerSnapshot) {
                                              final customer =
                                                  customerSnapshot.data;
                                              return Row(
                                                children: [
                                                  ProfileAvatarCircle.customer(
                                                    userId: activeRide.customerId,
                                                    name: customer?.name ?? '',
                                                    profilePhotoUrl:
                                                        customer?.profilePhotoUrl ??
                                                            '',
                                                    radius: 28,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          l10n.newRideRequest,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleLarge,
                                                        ),
                                                        if (customer?.name
                                                                .isNotEmpty ==
                                                            true)
                                                          Text(customer!.name),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          _TripLocationTile(
                                            icon: Icons.trip_origin,
                                            iconColor: const Color(0xFF16A34A),
                                            title: l10n.pickup,
                                            label: activeRide.pickupLabel,
                                          ),
                                          const SizedBox(height: 8),
                                          _TripLocationTile(
                                            icon: Icons.flag_rounded,
                                            iconColor: const Color(0xFFDC2626),
                                            title: l10n.destination,
                                            label: activeRide.destinationLabel,
                                          ),
                                          Text(
                                            '${l10n.cashFare}: ${fareService.formatIqd(activeRide.fareAmountIqd, locale: l10n.localeName)}',
                                          ),
                                          if (activeRide.status ==
                                              RideStatus.completed)
                                            RideEarningsSummary(
                                              ride: activeRide,
                                              showDriverNet: true,
                                            ),
                                          const SizedBox(height: 16),
                                          if (activeRide.status ==
                                              RideStatus.matched) ...[
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: _isActionPending(
                                                            activeRide.id,
                                                            'reject')
                                                        ? null
                                                        : () => _runRideAction(
                                                              rideId:
                                                                  activeRide.id,
                                                              action: 'reject',
                                                              task: () =>
                                                                  rideService
                                                                      .rejectRide(
                                                                rideId:
                                                                    activeRide
                                                                        .id,
                                                                driverId:
                                                                    driver.uid,
                                                              ),
                                                            ),
                                                    child: _isActionPending(
                                                            activeRide.id,
                                                            'reject')
                                                        ? const SizedBox(
                                                            height: 20,
                                                            width: 20,
                                                            child:
                                                                CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                          )
                                                        : Text(l10n.rejectRide),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _actionButton(
                                                    rideId: activeRide.id,
                                                    action: 'accept',
                                                    label: l10n.acceptRide,
                                                    onPressed: () => rideService
                                                        .acceptRide(
                                                      rideId: activeRide.id,
                                                      driverId: driver.uid,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (activeRide.status ==
                                              RideStatus.accepted)
                                            _actionButton(
                                              rideId: activeRide.id,
                                              action: 'start',
                                              label: l10n.startRide,
                                              onPressed: () => rideService
                                                  .startRide(activeRide.id),
                                            ),
                                          if (activeRide.status ==
                                              RideStatus.inProgress)
                                            _actionButton(
                                              rideId: activeRide.id,
                                              action: 'end',
                                              label: l10n.endRide,
                                              onPressed: () => rideService
                                                  .endRideAwaitingCash(
                                                activeRide.id,
                                              ),
                                            ),
                                          if (activeRide.status ==
                                                  RideStatus
                                                      .awaitingCashPayment &&
                                              !activeRide.cashCollectedByDriver)
                                            _actionButton(
                                              rideId: activeRide.id,
                                              action: 'cash',
                                              label: l10n.cashCollected,
                                              onPressed: () =>
                                                  _confirmCashCollected(
                                                activeRide,
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      RideChatScreen(
                                                    rideId: activeRide.id,
                                                    currentUserId: driver.uid,
                                                    currentUserRole:
                                                        UserRole.driver,
                                                    currentUserName:
                                                        driver.name,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.chat_bubble_outline,
                                            ),
                                            label: Text(l10n.openChat),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TripLocationTile extends StatelessWidget {
  const _TripLocationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
