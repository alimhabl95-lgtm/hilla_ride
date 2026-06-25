import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/chat_models.dart';
import 'package:uuid/uuid.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  Stream<List<RideMessage>> watchRideMessages(String rideId) {
    return _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RideMessage.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> sendRideMessage({
    required String rideId,
    required String senderId,
    required UserRole senderRole,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .doc(_uuid.v4())
        .set({
      'senderId': senderId,
      'senderRole': senderRole.name,
      'senderName': senderName,
      'text': trimmed,
      'type': RideMessageType.text.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendRideVoiceMessage({
    required String rideId,
    required String senderId,
    required UserRole senderRole,
    required String senderName,
    required String voiceUrl,
    required int voiceDurationMs,
  }) async {
    if (voiceUrl.trim().isEmpty) return;

    await _firestore
        .collection('rides')
        .doc(rideId)
        .collection('messages')
        .doc(_uuid.v4())
        .set({
      'senderId': senderId,
      'senderRole': senderRole.name,
      'senderName': senderName,
      'text': '',
      'type': RideMessageType.voice.value,
      'voiceUrl': voiceUrl,
      'voiceDurationMs': voiceDurationMs,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
