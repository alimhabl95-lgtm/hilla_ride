import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/widgets/animated_tuk_tuk.dart';
import 'package:hilla_ride/features/customer/screens/customer_splash_screen.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class ModeChooserScreen extends StatelessWidget {
  const ModeChooserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Center(child: AppLogoBadge(size: 120, borderRadius: 28)),
            const SizedBox(height: 20),
            Text(
              l10n.appTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.modeChooserSubtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _ModeTile(
              icon: Icons.person_pin_circle_outlined,
              title: l10n.takeRide,
              subtitle: l10n.takeRideDesc,
              color: AppBrandAssets.brandGold,
              onTap: () => _select(context, UserRole.customer),
            ),
            const SizedBox(height: 20),
            _ModeTile(
              title: l10n.driveAndEarn,
              subtitle: l10n.driveAndEarnDesc,
              color: AppBrandAssets.brandTealDark,
              leading: const TukTukTileIcon(
                size: 44,
                accentColor: AppBrandAssets.brandTealDark,
              ),
              onTap: () => _select(context, UserRole.driver),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, UserRole mode) {
    context.read<AppModeProvider>().selectMode(mode);
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    this.icon,
    this.leading,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: leading ??
                      Icon(icon, size: 36, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
