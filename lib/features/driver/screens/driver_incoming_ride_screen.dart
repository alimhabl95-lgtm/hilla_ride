import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/driver/widgets/driver_ride_map_panel.dart';
import 'package:hilla_ride/features/shared/screens/ride_chat_screen.dart';
import 'package:hilla_ride/features/shared/widgets/profile_avatar_circle.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Full incoming-offer UI. Prefer [initialRide] / cached offer so Accept /
/// Reject never waits forever on a blocked Firestore doc listen.
class DriverIncomingRideScreen extends StatefulWidget {
  const DriverIncomingRideScreen({
    super.key,
    required this.rideId,
    this.initialRide,
    this.driver,
    this.embedded = false,
  });

  final String rideId;
  final Ride? initialRide;
  final DriverProfile? driver;
  final bool embedded;

  @override
  State<DriverIncomingRideScreen> createState() =>
      _DriverIncomingRideScreenState();
}

class _DriverIncomingRideScreenState extends State<DriverIncomingRideScreen> {
  static const _fareService = FareService();
  var _busy = false;
  Ride? _ride;
  DriverProfile? _driver;
  String? _loadError;
  var _loading = true;
  StreamSubscription<DriverProfile?>? _driverSub;

  @override
  void initState() {
    super.initState();
    _driver = widget.driver;
    _ride = widget.initialRide ??
        (NotificationService.pendingDriverOfferRide?.id == widget.rideId
            ? NotificationService.pendingDriverOfferRide
            : null);
    if (_ride != null) {
      _loading = false;
    }
    unawaited(NotificationService.stopAlertSound());
    unawaited(_loadRide());
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchDriver());
  }

  @override
  void dispose() {
    unawaited(_driverSub?.cancel());
    super.dispose();
  }

  void _watchDriver() {
    if (!mounted) return;
    final uid = context.read<AppState>().authService.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    _driverSub = context.read<AppState>().driverService.watchDriver(uid).listen(
      (driver) {
        if (!mounted || driver == null) return;
        setState(() => _driver = driver);
      },
    );
  }

  Future<void> _loadRide() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (!doc.exists || doc.data() == null) {
        setState(() {
          _loading = false;
          if (_ride == null) {
            _loadError = 'Ride not found';
          }
        });
        return;
      }
      final ride = Ride.fromMap(doc.id, doc.data()!);
      setState(() {
        _ride = ride;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Keep cached ride so Accept / Reject still work.
        if (_ride == null) {
          _loadError = '$error';
        }
      });
    }
  }

  Future<void> _accept(Ride ride, String driverId) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<AppState>().rideService.acceptRide(
            rideId: ride.id,
            driverId: driverId,
          );
      if (!mounted) return;
      NotificationService.markAndroidDriverAccepted(ride.id);
      if (!NotificationService.isAndroid) {
        NotificationService.clearDriverRideOffer(ride.id);
      }
      unawaited(
        context.read<AppState>().driverService.ensureLocationUpdates(driverId),
      );
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        if (!widget.embedded) {
          Navigator.of(context, rootNavigator: true)
              .popUntil((route) => route.isFirst);
        }
      } else if (!widget.embedded) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      final isAr = l10n.localeName.startsWith('ar');
      final message = error is StateError && error.message == 'wallet_blocked'
          ? (isAr
              ? 'رصيد المحفظة غير كافٍ — اشحن المحفظة أولاً'
              : 'Wallet balance too low — recharge first')
          : '$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _busy = false);
    }
  }

  Future<void> _reject(Ride ride, String driverId) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      final appState = context.read<AppState>();
      final saveRejection =
          appState.driverMonthlyRideStatsService.recordRejection(
        driverId: driverId,
        rideId: ride.id,
      );
      await appState.rideService.rejectRide(
            rideId: ride.id,
            driverId: driverId,
          );
      await saveRejection;
      if (!mounted) return;
      NotificationService.suppressDriverRideOffer(ride.id);
      if (!widget.embedded) {
        Navigator.of(context).pop(false);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final appState = context.read<AppState>();
    final driverId = appState.authService.currentUser?.uid;
    final ride = _ride;
    final driver = _driver ?? widget.driver;

    final body = driverId == null
        ? Center(child: Text(isAr ? 'يلزم تسجيل الدخول' : 'Sign in required'))
        : _loading && ride == null
            ? const Center(child: CircularProgressIndicator())
            : ride == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _loadError ??
                                (isAr
                                    ? 'تعذّر تحميل الطلب'
                                    : 'Could not load ride request'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppPrimaryButton(
                            label: l10n.retry,
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _loadError = null;
                              });
                              unawaited(_loadRide());
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : ride.status != RideStatus.matched &&
                        ride.status != RideStatus.searching
                    ? _AlreadyHandled(
                        message: ride.status == RideStatus.accepted
                            ? (isAr ? 'تم قبول الرحلة' : 'Ride accepted')
                            : (isAr
                                ? 'الرحلة لم تعد متاحة'
                                : 'Ride is no longer available'),
                        onClose: () {
                          NotificationService.clearDriverRideOffer(ride.id);
                          if (!widget.embedded) {
                            Navigator.of(context).pop();
                          }
                        },
                      )
                    : Column(
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    AppBanner(
                                      message: l10n.newRideRequest,
                                      icon:
                                          Icons.notifications_active_outlined,
                                      tone: AppBannerTone.warning,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      _fareService.formatIqd(
                                        ride.fareAmountIqd,
                                        locale: l10n.localeName,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppBrandAssets.brandTealDark,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _Line(
                                      icon: Icons.trip_origin,
                                      color: AppBrandAssets.brandSuccess,
                                      title: l10n.pickup,
                                      label: ride.pickupLabel,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _Line(
                                      icon: Icons.flag_rounded,
                                      color: AppBrandAssets.brandDanger,
                                      title: l10n.destination,
                                      label: ride.destinationLabel,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: AppSecondaryButton(
                                            label: l10n.rejectRide,
                                            destructive: true,
                                            isLoading: _busy,
                                            onPressed: _busy
                                                ? null
                                                : () =>
                                                    _reject(ride, driverId),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: AppPrimaryButton(
                                            label: l10n.acceptRide,
                                            icon: Icons.check_rounded,
                                            isLoading: _busy,
                                            onPressed: _busy
                                                ? null
                                                : () =>
                                                    _accept(ride, driverId),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    StreamBuilder<AppUser?>(
                                      stream: appState.authService
                                          .watchUser(ride.customerId),
                                      builder: (context, customerSnap) {
                                        final customer = customerSnap.data;
                                        return Row(
                                          children: [
                                            ProfileAvatarCircle.customer(
                                              userId: ride.customerId,
                                              name: customer?.name ?? '',
                                              profilePhotoUrl:
                                                  customer?.profilePhotoUrl ??
                                                      '',
                                              radius: 20,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            Expanded(
                                              child: Text(
                                                customer?.name.isNotEmpty ==
                                                        true
                                                    ? customer!.name
                                                    : l10n.customerLabel,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: l10n.openChat,
                                              onPressed: driver == null
                                                  ? null
                                                  : () {
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              RideChatScreen(
                                                            rideId: ride.id,
                                                            currentUserId:
                                                                driver.uid,
                                                            currentUserRole:
                                                                UserRole
                                                                    .driver,
                                                            currentUserName:
                                                                driver.name,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                              icon: const Icon(
                                                Icons.chat_bubble_outline,
                                              ),
                                            ),
                                          ],
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

    if (widget.embedded) {
      return Material(color: Colors.white, child: body);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newRideRequest)),
      body: body,
    );
  }
}

class _AlreadyHandled extends StatelessWidget {
  const _AlreadyHandled({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(label: 'OK', onPressed: onClose),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.title,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppBrandAssets.brandMuted,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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
