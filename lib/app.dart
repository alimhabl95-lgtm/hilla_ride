import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/app_variant.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/theme/app_theme.dart';
import 'package:hilla_ride/features/admin/widgets/admin_profile_button.dart';
import 'package:hilla_ride/features/auth/screens/app_shell.dart';
import 'package:hilla_ride/features/customer/screens/customer_splash_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class HillaRideApp extends StatelessWidget {
  const HillaRideApp({
    super.key,
    required this.variant,
    required this.firebaseReady,
    this.firebaseError = '',
  });

  final AppVariant variant;
  final bool firebaseReady;
  final String firebaseError;

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final locale = localeProvider.locale ?? const Locale('ar');

    return MaterialApp(
      title: variant.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (deviceLocale, supported) {
        if (localeProvider.locale != null) return localeProvider.locale;
        if (deviceLocale != null) {
          for (final supportedLocale in supported) {
            if (supportedLocale.languageCode == deviceLocale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return const Locale('ar');
      },
      builder: (context, child) {
        final isRtl = Localizations.localeOf(context).languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: firebaseReady
          ? _RootScaffold(variant: variant)
          : FirebaseSetupScreen(error: firebaseError),
    );
  }
}

class _RootScaffold extends StatelessWidget {
  const _RootScaffold({required this.variant});

  final AppVariant variant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedMode = context.watch<AppModeProvider>().selectedMode;
    final authService = context.read<AppState>().authService;
    final title = variant.isWebAdmin ? l10n.adminPanelTitle : l10n.appTitle;

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        final isLoggedIn = authSnapshot.data != null;
        final onChooser =
            !variant.isWebAdmin && !isLoggedIn && selectedMode == null;
        final showBackToChooser =
            !variant.isWebAdmin && !isLoggedIn && selectedMode != null;

        return Scaffold(
          appBar: onChooser
              ? null
              : AppBar(
                  title: Text(title),
                  leading: showBackToChooser
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () =>
                              context.read<AppModeProvider>().clearMode(),
                        )
                      : null,
                  automaticallyImplyLeading: showBackToChooser,
                  actions: [
                    if (variant.isWebAdmin) const AdminProfileButton(),
                    if (!variant.isWebAdmin) const MobileAppBarActions(),
                    const LanguageToggle(),
                    if (isLoggedIn || variant.isWebAdmin) const LogoutButton(),
                  ],
                ),
          body: variant.isWebAdmin
              ? const AppShell()
              : const WelcomeSplashGate(child: AppShell()),
        );
      },
    );
  }
}
