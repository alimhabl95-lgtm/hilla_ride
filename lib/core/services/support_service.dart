import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/chat_models.dart';
import 'package:uuid/uuid.dart';

class SupportService {
  SupportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();
  static const _contactDoc = 'config/support';

  Future<SupportContactInfo> getContactInfo() async {
    try {
      final snapshot = await _firestore.doc(_contactDoc).get();
      return SupportContactInfo.fromMap(snapshot.data());
    } catch (_) {
      return SupportContactInfo.defaults;
    }
  }

  Future<void> saveContactInfo(SupportContactInfo info) async {
    await _firestore.doc(_contactDoc).set(
      {
        ...info.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<SupportMessage>> watchUserMessages(String userId) {
    return _firestore
        .collection('support_messages')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => SupportMessage.fromMap(doc.id, doc.data()))
          .toList();
      messages.sort(
        (a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return messages;
    });
  }

  Stream<List<SupportMessage>> watchAllMessages() {
    return _firestore.collection('support_messages').snapshots().map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => SupportMessage.fromMap(doc.id, doc.data()))
          .toList();
      messages.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return messages;
    });
  }

  Future<void> sendUserMessage({
    required String userId,
    required UserRole userRole,
    required String userName,
    required String phone,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    await _firestore.collection('support_messages').doc(_uuid.v4()).set({
      'userId': userId,
      'userRole': userRole.name,
      'userName': userName,
      'phone': phone,
      'message': trimmed,
      'isFromManager': false,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendManagerReply({
    required String userId,
    required String userName,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    await _firestore.collection('support_messages').doc(_uuid.v4()).set({
      'userId': userId,
      'userRole': UserRole.manager.name,
      'userName': userName,
      'phone': '',
      'message': trimmed,
      'isFromManager': true,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> closeThread(String userId) async {
    final snapshot = await _firestore
        .collection('support_messages')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'open')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.update({'status': 'closed'});
    }
  }
}
