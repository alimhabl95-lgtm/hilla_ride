import 'package:flutter/material.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/driver_monthly_ride_stats_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Android driver dashboard — completed/cancelled counts for today (local day).
class DriverDashboardDailyStatCards extends StatelessWidget {
  const DriverDashboardDailyStatCards({
    super.key,
    required this.driver,
  });

  final DriverProfile driver;

  static bool get isSupported => isNativeMobileApp;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final statsService =
        context.read<AppState>().driverMonthlyRideStatsService;

    return StreamBuilder<DriverCalendarDayStats>(
      stream: statsService.watchTodayStats(driver.uid),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? DriverCalendarDayStats.zero;
        return Row(
          children: [
            Expanded(
              child: _DashboardDayStatCard(
                value: '${stats.completed}',
                label: isAr
                    ? 'رحلات اليوم المكتملة'
                    : 'Completed rides today',
                tint: const Color(0xFFE8F8F6),
                iconBackground: AppBrandAssets.brandSuccess,
                icon: Icons.check,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _DashboardDayStatCard(
                value: '${stats.cancelled}',
                label: isAr
                    ? 'رحلات اليوم الملغاة'
                    : 'Cancelled rides today',
                tint: const Color(0xFFFDECEC),
                iconBackground: AppBrandAssets.brandDanger,
                icon: Icons.close,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardDayStatCard extends StatelessWidget {
  const _DashboardDayStatCard({
    required this.value,
    required this.label,
    required this.tint,
    required this.iconBackground,
    required this.icon,
  });

  final String value;
  final String label;
  final Color tint;
  final Color iconBackground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppBrandAssets.brandNavy,
                  height: 1,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppBrandAssets.brandNavy.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  fontSize: 12,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
