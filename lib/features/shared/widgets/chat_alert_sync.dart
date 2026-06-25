import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/features/shared/screens/ride_chat_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class ChatAlertSync extends StatefulWidget {
  const ChatAlertSync({
    super.key,
    required this.mode,
    required this.child,
  });

  final UserRole mode;
  final Widget child;

  @override
  State<ChatAlertSync> createState() => _ChatAlertSyncState();
}

class _ChatAlertSyncState extends State<ChatAlertSync> {
  StreamSubscription<Ride?>? _rideSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSubscription;
  final _messagesReadyByRide = <String, bool>{};
  String? _activeRideId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    unawaited(_rideSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    super.dispose();
  }

  void _start() {
    final uid = context.read<AppState>().authService.currentUser?.uid;
    if (uid == null) return;

    final rideService = context.read<AppState>().rideService;
    final rideStream = widget.mode == UserRole.driver
        ? rideService.watchAssignedRideForDriver(uid)
        : rideService.watchActiveRideForCustomer(uid);

    _rideSubscription = rideStream.listen((ride) {
      final nextRideId = ride?.id;
      if (nextRideId == _activeRideId) return;

      _activeRideId = nextRideId;
      unawaited(_messageSubscription?.cancel());
      _messageSubscription = null;

      if (nextRideId == null) return;

      _messagesReadyByRide[nextRideId] = false;
      _messageSubscription = FirebaseFirestore.instance
          .collection('rides')
          .doc(nextRideId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .listen((snapshot) => _onMessages(snapshot, uid, nextRideId));
    });
  }

  void _onMessages(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
    String rideId,
  ) {
    if (!_messagesReadyByRide.putIfAbsent(rideId, () => false)) {
      _messagesReadyByRide[rideId] = true;
      return;
    }

    if (!mounted) return;
    if (RideChatScreen.foregroundRideId == rideId) return;

    final l10n = AppLocalizations.of(context)!;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data();
      if (data == null) continue;

      final senderId = data['senderId'] as String? ?? '';
      final senderRole = UserRoleX.fromString(data['senderRole'] as String?);
      if (senderId == uid || senderRole == widget.mode) continue;

      final senderName = data['senderName'] as String? ?? l10n.appTitle;
      final voiceUrl = data['voiceUrl'] as String? ?? '';
      final type = data['type'] as String? ?? '';
      final isVoice = type == 'voice' || voiceUrl.isNotEmpty;
      final text = (data['text'] as String? ?? '').trim();
      final preview = isVoice ? l10n.voiceMessageLabel : text;

      unawaited(
        NotificationService.notifyChatMessage(
          title: widget.mode == UserRole.customer
              ? l10n.chatWithDriver
              : l10n.chatWithCustomer,
          body: preview.isEmpty ? senderName : '$senderName: $preview',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
