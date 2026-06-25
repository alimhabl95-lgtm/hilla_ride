import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/config/app_variant.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/features/admin/screens/admin_dashboard_screen.dart';
import 'package:hilla_ride/features/auth/screens/missing_profile_recovery_screen.dart';
import 'package:hilla_ride/features/auth/screens/mode_chooser_screen.dart';
import 'package:hilla_ride/features/auth/screens/admin_login_screen.dart';
import 'package:hilla_ride/features/auth/screens/login_screen.dart';
import 'package:hilla_ride/features/customer/widgets/customer_app_entry.dart';
import 'package:hilla_ride/features/customer/screens/customer_profile_screen.dart';
import 'package:hilla_ride/features/driver/screens/driver_home_screen.dart';
import 'package:hilla_ride/features/driver/screens/driver_registration_screen.dart';
import 'package:hilla_ride/features/manager/screens/manager_home_screen.dart';
import 'package:hilla_ride/features/shared/screens/ride_history_screen.dart';
import 'package:hilla_ride/features/shared/screens/support_screen.dart';
import 'package:hilla_ride/features/shared/screens/user_profile_screen.dart';
import 'package:hilla_ride/features/auth/widgets/session_guard.dart';
import 'package:hilla_ride/features/shared/widgets/announcement_icon_button.dart';
import 'package:hilla_ride/features/shared/widgets/current_ride_icon_button.dart';
import 'package:hilla_ride/features/shared/widgets/legal_documents_button.dart';
import 'package:hilla_ride/features/shared/widgets/chat_alert_sync.dart';
import 'package:hilla_ride/features/shared/widgets/ride_alert_overlay.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.variant.isWebAdmin) {
      return const _AdminShell();
    }
    return const _MobileShell();
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AppState>().authService;
    final modeProvider = context.watch<AppModeProvider>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser != null) {
          return const RideAlertOverlay(
            child: FcmTokenSync(
              child: SessionGuard(
                child: _LoggedInMobileShell(),
              ),
            ),
          );
        }

        if (!modeProvider.hasRestored) {
          return const Center(child: CircularProgressIndicator());
        }

        final mode = modeProvider.selectedMode;
        if (mode == null) {
          return const ModeChooserScreen();
        }

        return LoginScreen(selectedMode: mode);
      },
    );
  }
}

class _LoggedInMobileShell extends StatelessWidget {
  const _LoggedInMobileShell();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AppState>().authService;

    return StreamBuilder<AppUser?>(
      stream: authService.watchCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data;
        if (profile == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const MissingProfileRecoveryScreen();
        }

        if (profile.role == UserRole.customer || profile.role == UserRole.driver) {
          final modeProvider = context.read<AppModeProvider>();
          if (modeProvider.selectedMode != profile.role) {
            modeProvider.selectMode(profile.role);
          }
        }

        if (profile.role == UserRole.driver) {
          return AnnouncementSync(
            audience: 'drivers',
            child: RideAlertSync(
              mode: UserRole.driver,
              child: ChatAlertSync(
                mode: UserRole.driver,
                child: _DriverFlow(phone: profile.phone),
              ),
            ),
          );
        }

        if (profile.role == UserRole.customer) {
          if (!profile.isProfileComplete) {
            return const CustomerProfileScreen();
          }
          if (profile.isBlocked) {
            return const CustomerBlockedScreen();
          }
          return AnnouncementSync(
            audience: 'customers',
            child: RideAlertSync(
              mode: UserRole.customer,
              child: ChatAlertSync(
                mode: UserRole.customer,
                child: CustomerAppEntry(user: profile),
              ),
            ),
          );
        }

        return const ModeChooserScreen();
      },
    );
  }
}

class _AdminShell extends StatelessWidget {
  const _AdminShell();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AppState>().authService;

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return const AdminLoginScreen();
        }

        return StreamBuilder<AppUser?>(
          stream: authService.watchCurrentProfile(),
          builder: (context, profileSnapshot) {
            final profile = profileSnapshot.data;
            if (profile == null) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return const MissingProfileRecoveryScreen();
            }
            if (profile.isBlocked) {
              return const _ManagerAccessDenied();
            }
            if (profile.role == UserRole.manager && !profile.isProfileComplete) {
              return const ManagerProfileSetupScreen();
            }
            if (!profile.isAdminUser) {
              return const _ManagerAccessDenied();
            }
            return AdminDashboardScreen(adminUser: profile);
          },
        );
      },
    );
  }
}

class _ManagerAccessDenied extends StatelessWidget {
  const _ManagerAccessDenied();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            Text(l10n.managerAccessDenied, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<AppState>().authService.signOut(),
              child: Text(l10n.logout),
            ),
          ],
        ),
      ),
    );
  }
}

class FcmTokenSync extends StatefulWidget {
  const FcmTokenSync({super.key, required this.child});

  final Widget child;

  @override
  State<FcmTokenSync> createState() => _FcmTokenSyncState();
}

class _FcmTokenSyncState extends State<FcmTokenSync> {
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      NotificationService.tokenRefresh().listen((_) => _syncToken());
    }
    _syncToken();
  }

  Future<void> _syncToken() async {
    if (!mounted) return;
    final auth = context.read<AppState>().authService;
    final user = auth.currentUser;
    if (user == null) return;

    var role = context.read<AppModeProvider>().selectedMode;
    role ??= (await auth.getCurrentProfile())?.role;
    if (role == null ||
        role == UserRole.manager ||
        role == UserRole.assistant) {
      return;
    }

    final token = await NotificationService.getToken();
    if (token == null || !mounted) return;

    await NotificationService.saveTokenForUser(
      firestore: FirebaseFirestore.instance,
      uid: user.uid,
      role: role,
      token: token,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AnnouncementSync extends StatefulWidget {
  const AnnouncementSync({
    super.key,
    required this.audience,
    required this.child,
  });

  final String audience;
  final Widget child;

  @override
  State<AnnouncementSync> createState() => _AnnouncementSyncState();
}

class _AnnouncementSyncState extends State<AnnouncementSync> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    NotificationService.startAnnouncementListener(
      firestore: FirebaseFirestore.instance,
      audience: widget.audience,
    );
  }

  @override
  void dispose() {
    NotificationService.stopAnnouncementListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class RideAlertSync extends StatefulWidget {
  const RideAlertSync({
    super.key,
    required this.mode,
    required this.child,
  });

  final UserRole mode;
  final Widget child;

  @override
  State<RideAlertSync> createState() => _RideAlertSyncState();
}

class _RideAlertSyncState extends State<RideAlertSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncListeners());
  }

  @override
  void didUpdateWidget(RideAlertSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncListeners();
    }
  }

  void _syncListeners() {
    final user = context.read<AppState>().authService.currentUser;
    if (user == null) return;

    NotificationService.startRideAlertListeners(
      firestore: FirebaseFirestore.instance,
      uid: user.uid,
      role: widget.mode,
    );
  }

  @override
  void dispose() {
    NotificationService.stopRideAlertListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DriverFlow extends StatelessWidget {
  const _DriverFlow({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().authService.currentUser;
    if (user == null) {
      return LoginScreen(selectedMode: UserRole.driver);
    }

    return StreamBuilder<DriverProfile?>(
      stream: context.read<AppState>().driverService.watchDriver(user.uid),
      builder: (context, snapshot) {
        final driver = snapshot.data;
        if (driver == null) {
          return DriverRegistrationScreen(phone: phone);
        }

        if (driver.isBlocked) {
          return const DriverBlockedScreen();
        }

        switch (driver.approvalStatus) {
          case DriverApprovalStatus.pending:
            return const DriverPendingScreen();
          case DriverApprovalStatus.rejected:
            return const DriverRejectedScreen();
          case DriverApprovalStatus.approved:
            return DriverHomeScreen(driver: driver);
        }
      },
    );
  }
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64),
              const SizedBox(height: 16),
              Text(l10n.firebaseSetupRequired, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(error, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileAppBarActions extends StatelessWidget {
  const MobileAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modeProvider = context.watch<AppModeProvider>();
    final authService = context.read<AppState>().authService;
    final uid = authService.currentUser?.uid;
    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<AppUser?>(
      stream: authService.watchCurrentProfile(),
      builder: (context, profileSnapshot) {
        final mode = modeProvider.selectedMode ?? profileSnapshot.data?.role;
        if (mode != UserRole.customer && mode != UserRole.driver) {
          return const SizedBox.shrink();
        }
        final role = mode!;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CurrentRideIconButton(role: role),
            const LegalDocumentsButton(),
            AnnouncementIconButton(role: role),
            IconButton(
              tooltip: l10n.myProfileTitle,
              icon: const Icon(Icons.person_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(role: role),
                  ),
                );
              },
            ),
            if (role == UserRole.driver) ...[
              IconButton(
                tooltip: l10n.completedRidesCount,
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideHistoryScreen(
                        driverId: uid,
                        statusFilter: RideStatus.completed,
                        title: l10n.completedRidesCount,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: l10n.cancelledRidesCount,
                icon: const Icon(Icons.cancel_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideHistoryScreen(
                        driverId: uid,
                        statusFilter: RideStatus.cancelled,
                        title: l10n.cancelledRidesCount,
                      ),
                    ),
                  );
                },
              ),
            ] else if (role == UserRole.customer)
              IconButton(
                tooltip: l10n.myTripsTitle,
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideHistoryScreen(
                        customerId: uid,
                        title: l10n.myTripsTitle,
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              tooltip: l10n.supportTitle,
              icon: const Icon(Icons.support_agent_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportScreen()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      onSelected: localeProvider.setLocale,
      itemBuilder: (context) => [
        PopupMenuItem(value: const Locale('en'), child: Text(l10n.english)),
        PopupMenuItem(value: const Locale('ar'), child: Text(l10n.arabic)),
      ],
    );
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.logout,
      onPressed: () async {
        await context.read<AppState>().authService.signOut();
        if (context.mounted) {
          context.read<AppModeProvider>().clearMode();
        }
      },
      icon: const Icon(Icons.logout),
    );
  }
}
