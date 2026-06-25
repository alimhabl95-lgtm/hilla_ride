import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
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

class _FindingDriverScreenState extends State<FindingDriverScreen> {
  var _started = false;
  String? _error;
  var _waitingForDrivers = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _findDriver());
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
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
        appBar: AppBar(title: Text(l10n.findingDriverTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _findDriver,
                  child: Text(l10n.retry),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    if (widget.embedded) {
                      cancelCustomerRideAndExit(context, widget.rideId);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.searchingDriver,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _waitingForDrivers
                        ? l10n.noDriversInDistrict
                        : l10n.findingDriverSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  if (_waitingForDrivers) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.retry,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (ride != null && customerCanCancelRide(ride.status)) ...[
                    const SizedBox(height: 32),
                    OutlinedButton(
                      onPressed: () =>
                          cancelCustomerRideAndExit(context, widget.rideId),
                      child: Text(l10n.cancel),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
