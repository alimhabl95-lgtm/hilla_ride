import 'package:flutter/material.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/driver_monthly_ride_stats_service.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Android: month stats card; iOS: legacy side-by-side lifetime cards.
class DriverDashboardMonthlyStatCards extends StatelessWidget {
  const DriverDashboardMonthlyStatCards({
    super.key,
    required this.driver,
  });

  final DriverProfile driver;

  static bool get isSupported => isNativeMobileApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!isSupported) {
      return Row(
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
      );
    }

    final isAr = l10n.localeName.startsWith('ar');
    final statsService =
        context.read<AppState>().driverMonthlyRideStatsService;

    return StreamBuilder<DriverCalendarMonthStats>(
      stream: statsService.watchCalendarMonthStats(driver.uid),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? DriverCalendarMonthStats.zero;
        return AppCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr ? 'إحصائيات هذا الشهر' : 'This month\'s statistics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppBrandAssets.brandNavy,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppBrandAssets.brandTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppBrandAssets.brandTealDark,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: AppBrandAssets.brandMuted.withValues(alpha: 0.45),
                    ),
                    Expanded(
                      child: _MonthStatColumn(
                        value: '${stats.cancelled}',
                        label: isAr
                            ? 'الرحلات الملغاة هذا الشهر'
                            : 'Cancelled rides this month',
                        icon: Icons.close,
                        iconColor: AppBrandAssets.brandDanger,
                      ),
                    ),
                    VerticalDivider(
                      width: 24,
                      thickness: 1,
                      color: AppBrandAssets.brandMuted.withValues(alpha: 0.25),
                    ),
                    Expanded(
                      child: _MonthStatColumn(
                        value: '${stats.completed}',
                        label: isAr
                            ? 'الرحلات المكتملة هذا الشهر'
                            : 'Completed rides this month',
                        icon: Icons.check,
                        iconColor: AppBrandAssets.brandSuccess,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: AppBrandAssets.brandMuted.withValues(alpha: 0.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthStatColumn extends StatelessWidget {
  const _MonthStatColumn({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppBrandAssets.brandNavy,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppBrandAssets.brandMuted,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
        ),
      ],
    );
  }
}

/// Android bottom earnings summary on the driver dashboard.
class DriverDashboardEarningsSummary extends StatelessWidget {
  const DriverDashboardEarningsSummary({
    super.key,
    required this.driver,
  });

  final DriverProfile driver;

  static bool get isSupported => isNativeMobileApp;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final statsService =
        context.read<AppState>().driverMonthlyRideStatsService;

    return StreamBuilder<DriverCalendarMonthStats>(
      stream: statsService.watchCalendarMonthStats(driver.uid),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? DriverCalendarMonthStats.zero;
        final completed = stats.completed;
        final earnings = stats.earningsIqd;
        final fare = FareService();

        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppBrandAssets.brandNavy,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.monthlyRidesCount,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppBrandAssets.brandMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppBrandAssets.brandTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: AppBrandAssets.brandTealDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fare.formatIqd(earnings, locale: l10n.localeName),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppBrandAssets.brandTealDark,
                        ),
                  ),
                  Text(
                    l10n.yourEarningsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppBrandAssets.brandNavy,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
