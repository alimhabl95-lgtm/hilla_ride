import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/features/driver/widgets/driver_ride_offer_dialog.dart';

/// Shows alerts; driver ride requests open accept/reject popup (not full screen).
class RideAlertOverlay extends StatefulWidget {
  const RideAlertOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<RideAlertOverlay> createState() => _RideAlertOverlayState();
}

class _RideAlertOverlayState extends State<RideAlertOverlay> {
  StreamSubscription<RideAlertEvent>? _subscription;
  RideAlertEvent? _activeAlert;
  var _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _subscription = NotificationService.rideAlertStream.listen(_onAlert);
  }

  void _onAlert(RideAlertEvent event) {
    if (!mounted) return;

    if (event.type == RideAlertType.driverRideRequest) {
      final rideId = event.rideId ??
          NotificationService.pendingDriverOfferId.value ??
          '';
      if (rideId.isEmpty) return;
      unawaited(_showDriverOfferDialog(rideId));
      return;
    }

    setState(() => _activeAlert = event);
    unawaited(_showGenericAlertDialog(event));
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted || _activeAlert != event) return;
      setState(() => _activeAlert = null);
    });
  }

  Future<void> _showDriverOfferDialog(String rideId) async {
    if (_dialogVisible || !mounted) return;
    _dialogVisible = true;
    try {
      await DriverRideOfferDialog.showIfNeeded(
        context,
        rideId: rideId,
        initialRide: NotificationService.pendingDriverOfferRide?.id == rideId
            ? NotificationService.pendingDriverOfferRide
            : null,
      );
    } finally {
      _dialogVisible = false;
      NotificationService.stopAlertSound();
    }
  }

  Future<void> _showGenericAlertDialog(RideAlertEvent event) async {
    if (_dialogVisible || !mounted) return;
    _dialogVisible = true;

    final isChat = event.type == RideAlertType.chatMessage;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isChat ? Icons.chat_bubble : Icons.check_circle,
          color: isChat ? const Color(0xFF7C3AED) : const Color(0xFF0369A1),
          size: 48,
        ),
        title: Text(event.title),
        content: Text(event.body),
        actions: [
          FilledButton(
            onPressed: () {
              NotificationService.stopAlertSound();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _dialogVisible = false;
    NotificationService.stopAlertSound();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    NotificationService.stopAlertSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_activeAlert != null &&
            _activeAlert!.type != RideAlertType.driverRideRequest)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 8,
              color: _activeAlert!.type == RideAlertType.chatMessage
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF0369A1),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Icon(
                        _activeAlert!.type == RideAlertType.chatMessage
                            ? Icons.chat_bubble
                            : Icons.check_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeAlert!.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _activeAlert!.body,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          NotificationService.stopAlertSound();
                          setState(() => _activeAlert = null);
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
