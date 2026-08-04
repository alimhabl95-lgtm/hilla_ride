import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/features/customer/customer_ride_actions.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class FindingDriverScreen extends StatefulWidget {
  const FindingDriverScreen({
    super.key,
    required this.rideId,
    this.embedded = false,
  });

  final String rideId;
  final bool embedded;

  @override
  State<FindingDriverScreen> createState() => _FindingDriverScreenState();
}

class _FindingDriverScreenState extends State<FindingDriverScreen>
    with SingleTickerProviderStateMixin {
  var _started = false;
  String? _error;
  var _waitingForDrivers = false;
  Timer? _retryTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _findDriver());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _started = false);
      _findDriver();
    });
  }

  Future<void> _findDriver() async {
    if (_started) return;
    _started = true;
    setState(() {
      _error = null;
      _waitingForDrivers = false;
    });

    try {
      await context
          .read<AppState>()
          .rideService
          .assignNearestDriver(widget.rideId);
      _retryTimer?.cancel();
    } on StateError catch (error) {
      if (!mounted) return;
      if (error.message == 'no_drivers') {
        setState(() {
          _waitingForDrivers = true;
          _started = false;
        });
        _scheduleRetry();
        return;
      }
      if (error.message == 'ride_unavailable') {
        _retryTimer?.cancel();
        return;
      }
      setState(() {
        _error = error.message;
        _started = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _started = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rideService = context.read<AppState>().rideService;

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppBrandAssets.brandSurface,
        appBar: AppBar(title: Text(l10n.findingDriverTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppBrandAssets.brandDanger,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: l10n.retry,
                    onPressed: _findDriver,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppSecondaryButton(
                    label: l10n.cancel,
                    destructive: true,
                    onPressed: () {
                      if (widget.embedded) {
                        cancelCustomerRideAndExit(context, widget.rideId);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      appBar: AppBar(title: Text(l10n.findingDriverTitle)),
      body: StreamBuilder<Ride?>(
        stream: rideService.watchRide(widget.rideId),
        builder: (context, snapshot) {
          final ride = snapshot.data;
          if (ride != null &&
              ride.status == RideStatus.cancelled &&
              !_waitingForDrivers &&
              !widget.embedded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            });
          }

          if (ride != null &&
              ride.status == RideStatus.searching &&
              !_started &&
              !_waitingForDrivers) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _findDriver());
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: AppFloatingPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingSearchIndicator(controller: _pulseController),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      l10n.searchingDriver,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppBrandAssets.brandNavy,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _waitingForDrivers
                          ? l10n.noDriversInDistrict
                          : l10n.findingDriverSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppBrandAssets.brandMuted,
                          ),
                    ),
                    if (_waitingForDrivers) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.retry,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppBrandAssets.brandTealDark,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (ride != null && customerCanCancelRide(ride.status)) ...[
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
        },
      ),
    );
  }
}

class _PulsingSearchIndicator extends StatelessWidget {
  const _PulsingSearchIndicator({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Transform.scale(
                  scale: 0.5 + (controller.value + i / 3) % 1.0 * 0.7,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppBrandAssets.brandTeal.withValues(
                        alpha: 0.18 * (1 - ((controller.value + i / 3) % 1.0)),
                      ),
                    ),
                  ),
                ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppBrandAssets.brandTeal,
                      AppBrandAssets.brandTealDark,
                    ],
                  ),
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
