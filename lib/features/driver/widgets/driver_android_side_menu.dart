import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/driver/screens/driver_wallet_screen.dart';
import 'package:hilla_ride/features/shared/screens/announcements_screen.dart';
import 'package:hilla_ride/features/shared/screens/help_support_screen.dart';
import 'package:hilla_ride/features/shared/screens/legal_content_screen.dart';
import 'package:hilla_ride/features/shared/screens/ride_history_screen.dart';
import 'package:hilla_ride/features/shared/screens/user_profile_screen.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Android driver dashboard — RTL-friendly side menu (customer menu styling).
class DriverAndroidSideMenu extends StatelessWidget {
  const DriverAndroidSideMenu({
    super.key,
    required this.driver,
  });

  final DriverProfile driver;

  static bool get isSupported => isNativeMobileApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final uid = driver.uid;

    Future<void> closeAnd(VoidCallback action) async {
      Navigator.of(context).pop();
      action();
    }

    Future<void> logout() async {
      await context.read<AppState>().authService.signOut();
      if (context.mounted) {
        context.read<AppModeProvider>().clearMode();
      }
    }

    Widget item({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color,
    }) {
      return ListTile(
        leading: Icon(icon, color: color ?? AppBrandAssets.brandTealDark),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color ?? AppBrandAssets.brandNavy,
          ),
        ),
        onTap: () => closeAnd(onTap),
      );
    }

    Future<void> pickLanguage() async {
      final localeProvider = context.read<LocaleProvider>();
      final current = localeProvider.locale?.languageCode ?? 'ar';
      final picked = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l10n.language,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppBrandAssets.brandNavy,
                      ),
                ),
              ),
              for (final option in const [
                ('ar', 'العربية'),
                ('en', 'English'),
              ])
                ListTile(
                  leading: Icon(
                    option.$1 == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: AppBrandAssets.brandTealDark,
                  ),
                  title: Text(
                    option.$2,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(option.$1),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close the drawer
      if (picked != null && picked != current) {
        localeProvider.setLocale(Locale(picked));
      }
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    ProfileAvatarCircle.driver(
                      driverId: driver.uid,
                      name: driver.name,
                      profilePhotoUrl: driver.profilePhotoUrl,
                      radius: 26,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name.isEmpty
                                ? (isAr ? 'حساب السائق' : 'Driver')
                                : driver.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppBrandAssets.brandNavy,
                                ),
                          ),
                          Text(
                            isAr ? 'لوحة السائق' : 'Driver dashboard',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppBrandAssets.brandMuted,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: AppBrandAssets.brandMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    item(
                      icon: Icons.person_outline,
                      label: l10n.myProfileTitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const UserProfileScreen(role: UserRole.driver),
                          ),
                        );
                      },
                    ),
                    item(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.myTripsTitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RideHistoryScreen(
                              driverId: uid,
                              title: l10n.myTripsTitle,
                            ),
                          ),
                        );
                      },
                    ),
                    item(
                      icon: Icons.notifications_none,
                      label: l10n.announcementsTitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const AnnouncementsScreen(audience: 'drivers'),
                          ),
                        );
                      },
                    ),
                    item(
                      icon: Icons.account_balance_wallet_outlined,
                      label: isAr ? 'المحفظة' : 'Wallet',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DriverWalletScreen(driver: driver),
                          ),
                        );
                      },
                    ),
                    item(
                      icon: Icons.headset_mic_outlined,
                      label: l10n.supportTitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.language,
                        color: AppBrandAssets.brandTealDark,
                      ),
                      title: Text(
                        l10n.language,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppBrandAssets.brandNavy,
                        ),
                      ),
                      trailing: Text(
                        isAr ? 'العربية' : 'English',
                        style: const TextStyle(
                          color: AppBrandAssets.brandMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Sheet opens over the drawer; drawer closes afterwards.
                      onTap: () => unawaited(pickLanguage()),
                    ),
                    item(
                      icon: Icons.settings_outlined,
                      label: l10n.settingsTitle,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const UserProfileScreen(role: UserRole.driver),
                          ),
                        );
                      },
                    ),
                    item(
                      icon: Icons.lock_outline,
                      label: l10n.privacyPolicy,
                      onTap: () async {
                        final config = await context
                            .read<AppState>()
                            .appConfigService
                            .getConfig();
                        if (!context.mounted) return;
                        await LegalContentScreen.open(
                          context: context,
                          kind: LegalContentKind.privacy,
                          config: config,
                          languageCode: isAr ? 'ar' : 'en',
                        );
                      },
                    ),
                    const Divider(),
                    item(
                      icon: Icons.logout,
                      label: l10n.logout,
                      color: AppBrandAssets.brandDanger,
                      onTap: () => unawaited(logout()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
