import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/driver/screens/driver_rewards_screen.dart';
import 'package:hilla_ride/features/driver/screens/driver_wallet_screen.dart';
import 'package:hilla_ride/features/driver/widgets/driver_delivery_orders_panel.dart';
import 'package:hilla_ride/features/driver/widgets/driver_ride_map_panel.dart';
import 'package:hilla_ride/features/shared/widgets/announcement_banner.dart';
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
      final isAr = l10n.localeName.startsWith('ar');
      final message = error is StateError && error.message == 'work_area_required'
          ? l10n.driverWorkDistrictRequired
          : error is StateError && error.message == 'wallet_blocked'
              ? (isAr
                  ? 'رصيد المحفظة غير كافٍ — اشحن المحفظة أولاً'
                  : 'Wallet balance too low — recharge first')
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

  void _openWallet(DriverProfile driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverWalletScreen(driver: driver),
      ),
    );
  }

  Widget _actionButton({
    required String rideId,
    required String action,
    required String label,
    required Future<void> Function() onPressed,
    IconData? icon,
  }) {
    return AppPrimaryButton(
      label: label,
      icon: icon,
      isLoading: _isActionPending(rideId, action),
      onPressed: _isActionPending(rideId, action)
          ? null
          : () => _runRideAction(
                rideId: rideId,
                action: action,
                task: onPressed,
              ),
    );
  }

  String _availabilityHint(DriverProfile driver, AppLocalizations l10n) {
    if (!driver.hasAssignedWorkArea) {
      return l10n.driverWorkDistrictRequired;
    }
    return driver.isOnline ? l10n.waitingForRides : l10n.goOnline;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final rideService = context.read<AppState>().rideService;
    const fareService = FareService();

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Material(
                    color: AppBrandAssets.brandTeal.withValues(alpha: 0.15),
                    shape: const CircleBorder(),
                    child: PopupMenuButton<String>(
                      tooltip: isAr ? 'القائمة' : 'Menu',
                      offset: const Offset(0, 48),
                      icon: const Icon(
                        Icons.menu,
                        color: AppBrandAssets.brandTealDark,
                      ),
                      onSelected: (value) async {
                        switch (value) {
                          case 'wallet':
                            _openWallet(widget.driver);
                          case 'rewards':
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DriverRewardsScreen(
                                  driver: widget.driver,
                                ),
                              ),
                            );
                          case 'logout':
                            await context.read<AppState>().authService.signOut();
                            if (context.mounted) {
                              context.read<AppModeProvider>().clearMode();
                            }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'wallet',
                          child: Text(isAr ? 'المحفظة' : 'Wallet'),
                        ),
                        PopupMenuItem(
                          value: 'rewards',
                          child: Text(isAr ? 'المكافآت' : 'Rewards'),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: Text(l10n.logout),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isAr ? 'لوحة السائق' : 'Driver dashboard',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppBrandAssets.brandNavy,
                          ),
                    ),
                  ),
                  AppCircleIconButton(
                    tooltip: isAr ? 'المحفظة' : 'Wallet',
                    icon: Icons.account_balance_wallet_outlined,
                    backgroundColor:
                        AppBrandAssets.brandTeal.withValues(alpha: 0.15),
                    foregroundColor: AppBrandAssets.brandTealDark,
                    onPressed: () => _openWallet(widget.driver),
                  ),
                ],
              ),
            ),
          ),
          const AnnouncementBanner(audience: 'drivers'),
          Expanded(
            child: StreamBuilder<DriverProfile?>(
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: AppBanner(
                        message: l10n.driverWorkDistrictRequired,
                        icon: Icons.location_city_outlined,
                        tone: AppBannerTone.danger,
                      ),
                    ),
                  StreamBuilder<WalletConfig>(
                    stream:
                        context.read<AppState>().walletService.watchConfig(),
                    builder: (context, configSnap) {
                      final config = configSnap.data ?? const WalletConfig();
                      final low = driver.walletBalanceIqd <=
                          config.lowBalanceWarningIqd;
                      final blocked = driver.walletStatus == 'blocked' ||
                          driver.walletBalanceIqd < config.minBalanceIqd;
                      if (!low && !blocked) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          0,
                        ),
                        child: AppBanner(
                          message: blocked
                              ? (isAr
                                  ? 'المحفظة محظورة — اشحن لاستقبال الرحلات'
                                  : 'Wallet blocked — recharge to receive trips')
                              : (isAr
                                  ? 'رصيد المحفظة منخفض'
                                  : 'Wallet balance is low'),
                          icon: Icons.account_balance_wallet_outlined,
                          tone: blocked
                              ? AppBannerTone.danger
                              : AppBannerTone.warning,
                          onTap: () => _openWallet(driver),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (activeRide == null) {
                          return _IdleDriverPanel(
                            driver: driver,
                            l10n: l10n,
                            fareService: fareService,
                            isUpdatingOnline: _isUpdatingOnline,
                            onToggleOnline: _toggleOnline,
                            onOpenWallet: () => _openWallet(driver),
                            availabilityHint: _availabilityHint(driver, l10n),
                          );
                        }

                        return _ActiveRidePanel(
                          ride: activeRide,
                          driver: driver,
                          l10n: l10n,
                          fareService: fareService,
                          isActionPending: _isActionPending,
                          runRideAction: _runRideAction,
                          actionButton: _actionButton,
                          onConfirmCash: _confirmCashCollected,
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
          ),
        ],
      ),
    );
  }
}

class _IdleDriverPanel extends StatelessWidget {
  const _IdleDriverPanel({
    required this.driver,
    required this.l10n,
    required this.fareService,
    required this.isUpdatingOnline,
    required this.onToggleOnline,
    required this.onOpenWallet,
    required this.availabilityHint,
  });

  final DriverProfile driver;
  final AppLocalizations l10n;
  final FareService fareService;
  final bool isUpdatingOnline;
  final Future<void> Function(bool) onToggleOnline;
  final VoidCallback onOpenWallet;
  final String availabilityHint;

  @override
  Widget build(BuildContext context) {
    final isAr = l10n.localeName.startsWith('ar');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            ProfileAvatarCircle.driver(
              driverId: driver.uid,
              name: driver.name,
              profilePhotoUrl: driver.profilePhotoUrl,
              radius: 28,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'مرحباً' : 'Welcome',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppBrandAssets.brandMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    driver.name.isEmpty
                        ? (isAr ? 'حساب السائق' : 'Driver')
                        : driver.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppBrandAssets.brandNavy,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: onOpenWallet,
              style: IconButton.styleFrom(
                foregroundColor: AppBrandAssets.brandTealDark,
                backgroundColor:
                    AppBrandAssets.brandTeal.withValues(alpha: 0.12),
              ),
              icon: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: driver.isOnline
                          ? AppBrandAssets.brandSuccess
                          : AppBrandAssets.brandMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isAr ? 'الحالة' : 'Availability',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppBrandAssets.brandNavy,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (driver.isOnline
                              ? AppBrandAssets.brandSuccess
                              : AppBrandAssets.brandMuted)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      driver.isOnline
                          ? (isAr ? 'متصل' : 'Online')
                          : (isAr ? 'غير متصل' : 'Offline'),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: driver.isOnline
                            ? AppBrandAssets.brandSuccess
                            : AppBrandAssets.brandMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                availabilityHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: driver.hasAssignedWorkArea
                          ? AppBrandAssets.brandMuted
                          : AppBrandAssets.brandDanger,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (isUpdatingOnline)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppBrandAssets.brandTeal,
                    ),
                  ),
                )
              else if (driver.isOnline)
                AppSecondaryButton(
                  label: isAr ? 'إيقاف العمل' : 'Go offline',
                  icon: Icons.pause_circle_filled,
                  onPressed: !driver.hasAssignedWorkArea
                      ? null
                      : () => onToggleOnline(false),
                )
              else
                AppPrimaryButton(
                  label: isAr ? 'ابدأ استقبال الطلبات' : 'Go online',
                  icon: Icons.play_circle_filled,
                  onPressed: !driver.hasAssignedWorkArea
                      ? null
                      : () => onToggleOnline(true),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppWalletCard(
          title: isAr ? 'رصيد المحفظة' : 'Wallet balance',
          balanceLabel: fareService.formatIqd(
            driver.walletBalanceIqd,
            locale: l10n.localeName,
          ),
          subtitle: driver.isOnline
              ? (isAr ? 'متصل — بانتظار الطلبات' : 'Online — waiting for trips')
              : (isAr ? 'غير متصل' : 'Offline'),
          actionLabel: isAr ? 'فتح المحفظة / شحن' : 'Open wallet / recharge',
          onAction: onOpenWallet,
        ),
        const SizedBox(height: AppSpacing.lg),
        DriverDeliveryOrdersPanel(driverId: driver.uid),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppStatCard(
                label: l10n.completedRidesCount,
                value: '${driver.completedRidesCount}',
                icon: Icons.check_circle_outline,
                accent: AppBrandAssets.brandTealDark,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppStatCard(
                label: l10n.cancelledRidesCount,
                value: '${driver.cancelledRidesCount}',
                icon: Icons.cancel_outlined,
                accent: AppBrandAssets.brandDanger,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
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

            return AppCard(
              color: AppBrandAssets.brandTeal.withValues(alpha: 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppBrandAssets.brandGold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          color: AppBrandAssets.brandGoldDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.driverMonthlyPrizeTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.driverMonthlyRideCount(stats.rideCount),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppBrandAssets.brandNavy,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.driverMonthlyRank(stats.rank, stats.rideCount)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.driverMonthlyPrizeAmount(
                      fareService.formatIqd(
                        stats.prizeAmountIqd,
                        locale: l10n.localeName,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppBrandAssets.brandGoldDark,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.yourEarningsTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppBrandAssets.brandNavy,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              _EarningsRow(
                label: l10n.monthlyRidesCount,
                value: '${driver.monthlyRideCount}',
              ),
              _EarningsRow(
                label: l10n.completedRidesCount,
                value: '${driver.completedRidesCount}',
              ),
              if (driver.pendingBonusIqd > 0)
                _EarningsRow(
                  label: l10n.pendingBonusLabel,
                  value: fareService.formatIqd(
                    driver.pendingBonusIqd,
                    locale: l10n.localeName,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Text(
            driver.isOnline ? l10n.waitingForRides : l10n.goOnline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppBrandAssets.brandMuted,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppBrandAssets.brandMuted,
                  ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                  color: emphasized
                      ? AppBrandAssets.brandTealDark
                      : AppBrandAssets.brandNavy,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActiveRidePanel extends StatelessWidget {
  const _ActiveRidePanel({
    required this.ride,
    required this.driver,
    required this.l10n,
    required this.fareService,
    required this.isActionPending,
    required this.runRideAction,
    required this.actionButton,
    required this.onConfirmCash,
  });

  final Ride ride;
  final DriverProfile driver;
  final AppLocalizations l10n;
  final FareService fareService;
  final bool Function(String rideId, String action) isActionPending;
  final Future<void> Function({
    required String rideId,
    required String action,
    required Future<void> Function() task,
  }) runRideAction;
  final Widget Function({
    required String rideId,
    required String action,
    required String label,
    required Future<void> Function() onPressed,
    IconData? icon,
  }) actionButton;
  final Future<void> Function(Ride ride) onConfirmCash;

  @override
  Widget build(BuildContext context) {
    final rideService = context.read<AppState>().rideService;
    final isMatched = ride.status == RideStatus.matched;

    return Column(
      children: [
        Expanded(
          child: DriverRideMapPanel(
            ride: ride,
            driver: driver,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: AppFloatingPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMatched)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppBanner(
                        message: l10n.newRideRequest,
                        icon: Icons.notifications_active_outlined,
                        tone: AppBannerTone.warning,
                      ),
                    ),
                  StreamBuilder<AppUser?>(
                    stream: context
                        .read<AppState>()
                        .authService
                        .watchUser(ride.customerId),
                    builder: (context, customerSnapshot) {
                      final customer = customerSnapshot.data;
                      return Row(
                        children: [
                          ProfileAvatarCircle.customer(
                            userId: ride.customerId,
                            name: customer?.name ?? '',
                            profilePhotoUrl: customer?.profilePhotoUrl ?? '',
                            radius: 28,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.newRideRequest,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppBrandAssets.brandNavy,
                                      ),
                                ),
                                if (customer?.name.isNotEmpty == true)
                                  Text(
                                    customer!.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppBrandAssets.brandMuted,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppBrandAssets.brandGold
                                  .withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              fareService.formatIqd(
                                ride.fareAmountIqd,
                                locale: l10n.localeName,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppBrandAssets.brandGoldDark,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TripLocationTile(
                    icon: Icons.trip_origin,
                    iconColor: AppBrandAssets.brandSuccess,
                    title: l10n.pickup,
                    label: ride.pickupLabel,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TripLocationTile(
                    icon: Icons.flag_rounded,
                    iconColor: AppBrandAssets.brandDanger,
                    title: l10n.destination,
                    label: ride.destinationLabel,
                  ),
                  if (ride.status == RideStatus.completed) ...[
                    const SizedBox(height: AppSpacing.md),
                    RideEarningsSummary(
                      ride: ride,
                      showDriverNet: true,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (isMatched) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppSecondaryButton(
                            label: l10n.rejectRide,
                            destructive: true,
                            onPressed: isActionPending(ride.id, 'reject')
                                ? null
                                : () => runRideAction(
                                      rideId: ride.id,
                                      action: 'reject',
                                      task: () => rideService.rejectRide(
                                        rideId: ride.id,
                                        driverId: driver.uid,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: actionButton(
                            rideId: ride.id,
                            action: 'accept',
                            label: l10n.acceptRide,
                            icon: Icons.check_rounded,
                            onPressed: () async {
                              try {
                                await rideService.acceptRide(
                                  rideId: ride.id,
                                  driverId: driver.uid,
                                );
                              } catch (error) {
                                if (!context.mounted) return;
                                final isAr =
                                    l10n.localeName.startsWith('ar');
                                final message = error is StateError &&
                                        error.message == 'wallet_blocked'
                                    ? (isAr
                                        ? 'رصيد المحفظة غير كافٍ — اشحن المحفظة أولاً'
                                        : 'Wallet balance too low — recharge first')
                                    : '$error';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (ride.status == RideStatus.accepted)
                    actionButton(
                      rideId: ride.id,
                      action: 'start',
                      label: l10n.startRide,
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => rideService.startRide(ride.id),
                    ),
                  if (ride.status == RideStatus.inProgress)
                    actionButton(
                      rideId: ride.id,
                      action: 'end',
                      label: l10n.endRide,
                      icon: Icons.flag_circle_outlined,
                      onPressed: () =>
                          rideService.endRideAwaitingCash(ride.id),
                    ),
                  if (ride.status == RideStatus.awaitingCashPayment &&
                      !ride.cashCollectedByDriver)
                    actionButton(
                      rideId: ride.id,
                      action: 'cash',
                      label: l10n.cashCollected,
                      icon: Icons.payments_outlined,
                      onPressed: () => onConfirmCash(ride),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppSecondaryButton(
                    label: l10n.openChat,
                    icon: Icons.chat_bubble_outline,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RideChatScreen(
                            rideId: ride.id,
                            currentUserId: driver.uid,
                            currentUserRole: UserRole.driver,
                            currentUserName: driver.name,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppBrandAssets.brandMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppBrandAssets.brandNavy,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
