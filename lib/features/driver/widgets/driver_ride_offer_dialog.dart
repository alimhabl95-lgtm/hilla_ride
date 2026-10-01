import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Accept / reject popup for new ride offers (no full-screen map first).
class DriverRideOfferDialog {
  DriverRideOfferDialog._();

  static String? _showingRideId;

  static Future<void> showIfNeeded(
    BuildContext context, {
    required String rideId,
    Ride? initialRide,
  }) async {
    if (rideId.isEmpty) return;
    if (_showingRideId == rideId) return;
    if (NotificationService.wasDriverOfferSuppressed(rideId)) return;

    _showingRideId = rideId;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _DriverRideOfferDialogBody(
          rideId: rideId,
          initialRide: initialRide,
        ),
      );
    } finally {
      if (_showingRideId == rideId) _showingRideId = null;
    }
  }
}

class _DriverRideOfferDialogBody extends StatefulWidget {
  const _DriverRideOfferDialogBody({
    required this.rideId,
    this.initialRide,
  });

  final String rideId;
  final Ride? initialRide;

  @override
  State<_DriverRideOfferDialogBody> createState() =>
      _DriverRideOfferDialogBodyState();
}

class _DriverRideOfferDialogBodyState extends State<_DriverRideOfferDialogBody> {
  static const _fare = FareService();
  Ride? _ride;
  var _busy = false;
  var _loading = true;
  var _closed = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideStatusSub;

  void _closeDialog() {
    if (!mounted || _closed) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  void _closeIfOfferWithdrawn() {
    if (NotificationService.pendingDriverOfferId.value != widget.rideId) {
      _closeDialog();
    }
  }

  void _onRideSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted || _closed) return;
    if (!snapshot.exists) {
      _closeDialog();
      return;
    }
    final data = snapshot.data();
    final status = data?['status'] as String? ?? '';
    if (status == RideStatus.cancelled.value) {
      _closeDialog();
      return;
    }
    final driverId =
        context.read<AppState>().authService.currentUser?.uid ?? '';
    final rejected = (data?['rejectedDriverIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .contains(driverId) ??
        false;
      if (driverId.isNotEmpty && rejected) {
        _closeDialog();
        return;
      }
    final assigned = data?['driverId'];
    final taken = assigned is String &&
        assigned.isNotEmpty &&
        driverId.isNotEmpty &&
        assigned != driverId;
    if (taken &&
        (status == RideStatus.accepted.value ||
            status == RideStatus.inProgress.value ||
            status == RideStatus.completed.value)) {
      _closeDialog();
    }
  }

  @override
  void initState() {
    super.initState();
    NotificationService.pendingDriverOfferId.addListener(_closeIfOfferWithdrawn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rideStatusSub = FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .snapshots()
          .listen(_onRideSnapshot);
    });
    _ride = widget.initialRide ??
        (NotificationService.pendingDriverOfferRide?.id == widget.rideId
            ? NotificationService.pendingDriverOfferRide
            : null);
    _loading = _ride == null;
    unawaited(_loadRide());
  }

  @override
  void dispose() {
    NotificationService.pendingDriverOfferId
        .removeListener(_closeIfOfferWithdrawn);
    unawaited(_rideStatusSub?.cancel());
    super.dispose();
  }

  Future<void> _loadRide() async {
    if (_ride != null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        setState(() {
          _ride = Ride.fromMap(doc.id, doc.data()!);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(Ride ride, String driverId) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
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
      NotificationService.stopAlertSound();
      _closeDialog();
    } catch (error) {
      if (!mounted) return;
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
      final saveRejection = appState.driverMonthlyRideStatsService.recordRejection(
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
      NotificationService.stopAlertSound();
      _closeDialog();
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
    final driverId = context.read<AppState>().authService.currentUser?.uid;
    final ride = _ride;

    return AlertDialog(
      icon: const Icon(
        Icons.notifications_active,
        color: AppBrandAssets.brandTealDark,
        size: 48,
      ),
      title: Text(l10n.newRideRequest),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          : ride == null
              ? Text(
                  isAr ? 'تعذّر تحميل تفاصيل الرحلة' : 'Could not load ride details',
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fare.formatIqd(
                          ride.fareAmountIqd,
                          locale: l10n.localeName,
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppBrandAssets.brandTealDark,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${l10n.pickup}: ${ride.pickupLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${l10n.destination}: ${ride.destinationLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        SizedBox(
          width: 130,
          child: AppSecondaryButton(
            label: l10n.rejectRide,
            destructive: true,
            isLoading: _busy,
            onPressed: _busy || driverId == null || ride == null
                ? null
                : () => _reject(ride, driverId),
          ),
        ),
        SizedBox(
          width: 130,
          child: AppPrimaryButton(
            label: l10n.acceptRide,
            icon: Icons.check_rounded,
            isLoading: _busy,
            onPressed: _busy || driverId == null || ride == null
                ? null
                : () => _accept(ride, driverId),
          ),
        ),
      ],
    );
  }
}
