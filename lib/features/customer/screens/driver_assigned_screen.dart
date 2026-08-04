import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/customer/customer_ride_actions.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DriverAssignedScreen extends StatefulWidget {
  const DriverAssignedScreen({
    super.key,
    required this.rideId,
    this.embedded = false,
  });

  final String rideId;
  final bool embedded;

  @override
  State<DriverAssignedScreen> createState() => _DriverAssignedScreenState();
}

class _DriverAssignedScreenState extends State<DriverAssignedScreen> {
  var _notifiedAccepted = false;
  static const _fareService = FareService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;
    final driverService = context.read<AppState>().driverService;

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      appBar: AppBar(title: Text(l10n.driverAssignedTitle)),
      body: StreamBuilder<Ride?>(
        stream: rideService.watchRide(widget.rideId),
        builder: (context, rideSnapshot) {
          final ride = rideSnapshot.data;
          if (ride == null) {
            return const AppLoadingState();
          }

          if (ride.status == RideStatus.cancelled && !widget.embedded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            });
            return const SizedBox.shrink();
          }

          if (ride.status == RideStatus.accepted && !_notifiedAccepted) {
            _notifiedAccepted = true;
            NotificationService.notifyCustomerRideAccepted(ride);
          }

          final driverId = ride.driverId;
          if (driverId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: AppFloatingPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppBrandAssets.brandTeal,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text(
                        ride.status == RideStatus.matched
                            ? l10n.waitingDriverAccept
                            : l10n.searchingDriver,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppBrandAssets.brandNavy,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      if (customerCanCancelRide(ride.status)) ...[
                        const SizedBox(height: AppSpacing.xxxl),
                        AppSecondaryButton(
                          label: l10n.cancel,
                          destructive: true,
                          onPressed: () =>
                              cancelCustomerRideAndExit(context, widget.rideId),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          return StreamBuilder<DriverProfile?>(
            stream: driverService.watchDriver(driverId),
            builder: (context, driverSnapshot) {
              final driver = driverSnapshot.data;
              final statusLabel = ride.status == RideStatus.matched
                  ? l10n.waitingDriverAccept
                  : l10n.driverFound;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppBanner(
                      message: statusLabel,
                      icon: ride.status == RideStatus.matched
                          ? Icons.hourglass_top
                          : Icons.check_circle_outline,
                      tone: ride.status == RideStatus.matched
                          ? AppBannerTone.warning
                          : AppBannerTone.success,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      child: Column(
                        children: [
                          ProfileAvatarCircle.driver(
                            driverId: driverId,
                            name: driver?.name ?? '',
                            profilePhotoUrl: driver?.profilePhotoUrl ?? '',
                            radius: 40,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            driver?.name ?? l10n.searchingDriver,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppBrandAssets.brandNavy,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final rating = driver?.rating ?? 5.0;
                              return Icon(
                                i < rating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: AppBrandAssets.brandGold,
                                size: 22,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppStatCard(
                            label: l10n.vehiclePlate,
                            value: driver?.vehiclePlate ?? '—',
                            icon: Icons.pin,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppStatCard(
                            label: l10n.cashFare,
                            value: _fareService.formatIqd(
                              ride.fareAmountIqd,
                              locale: l10n.localeName,
                            ),
                            icon: Icons.payments_outlined,
                            accent: AppBrandAssets.brandGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppBrandAssets.brandTeal
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadii.sm),
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: AppBrandAssets.brandTealDark,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driver?.vehicleType ?? '—',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppBrandAssets.brandNavy,
                                      ),
                                ),
                                if (driver?.vehicleColor.isNotEmpty ?? false)
                                  Text(
                                    driver!.vehicleColor,
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
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    if (customerCanCancelRide(ride.status))
                      AppSecondaryButton(
                        label: l10n.cancel,
                        destructive: true,
                        onPressed: () =>
                            cancelCustomerRideAndExit(context, widget.rideId),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
