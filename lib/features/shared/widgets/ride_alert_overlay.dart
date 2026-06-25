import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/services/notification_service.dart';

/// Shows a banner + modal when a ride alert fires (works on web + mobile).
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
    setState(() => _activeAlert = event);
    _showAlertDialog(event);
    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted || _activeAlert != event) return;
      setState(() => _activeAlert = null);
    });
  }

  Future<void> _showAlertDialog(RideAlertEvent event) async {
    if (_dialogVisible || !mounted) return;
    _dialogVisible = true;

    final isDriver = event.type == RideAlertType.driverRideRequest;
    final isChat = event.type == RideAlertType.chatMessage;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isDriver
              ? Icons.notifications_active
              : isChat
                  ? Icons.chat_bubble
                  : Icons.check_circle,
          color: isDriver
              ? const Color(0xFF0F766E)
              : isChat
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF0369A1),
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
        if (_activeAlert != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              elevation: 8,
              color: _activeAlert!.type == RideAlertType.driverRideRequest
                  ? const Color(0xFF0F766E)
                  : _activeAlert!.type == RideAlertType.chatMessage
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF0369A1),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Icon(
                        _activeAlert!.type == RideAlertType.driverRideRequest
                            ? Icons.notifications_active
                            : _activeAlert!.type == RideAlertType.chatMessage
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
