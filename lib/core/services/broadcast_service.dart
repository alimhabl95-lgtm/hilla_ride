import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BroadcastService {
  BroadcastService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<BroadcastResult> sendAnnouncement({
    required String audience,
    required String title,
    required String message,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedMessage = message.trim();
    if (trimmedTitle.isEmpty || trimmedMessage.isEmpty) {
      throw ArgumentError('Title and message required.');
    }

    try {
      return await _sendViaCloudFunction(
        audience: audience,
        title: trimmedTitle,
        message: trimmedMessage,
      );
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'sendBroadcast function unavailable (${error.code}), using Firestore.',
        );
      }
      return _sendViaFirestore(
        audience: audience,
        title: trimmedTitle,
        message: trimmedMessage,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('sendBroadcast failed: $error, using Firestore.');
      }
      return _sendViaFirestore(
        audience: audience,
        title: trimmedTitle,
        message: trimmedMessage,
      );
    }
  }

  Future<BroadcastResult> _sendViaCloudFunction({
    required String audience,
    required String title,
    required String message,
  }) async {
    final callable = _functions.httpsCallable('sendBroadcast');
    final result = await callable.call({
      'audience': audience,
      'title': title,
      'message': message,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return BroadcastResult(
      sent: (data['sent'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? 0,
      audience: data['audience'] as String? ?? audience,
      usedFirestore: false,
    );
  }

  Future<BroadcastResult> _sendViaFirestore({
    required String audience,
    required String title,
    required String message,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in required.');
    }

    final total = await _countAudience(audience);

    await _firestore.collection('announcements').add({
      'audience': audience,
      'title': title,
      'body': message,
      'sentCount': total,
      'totalTokens': total,
      'delivery': 'firestore',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return BroadcastResult(
      sent: total,
      total: total,
      audience: audience,
      usedFirestore: true,
    );
  }

  Future<int> _countAudience(String audience) async {
    if (audience == 'drivers') {
      final snapshot = await _firestore.collection('drivers').get();
      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['isBlocked'] == true || data['isRemoved'] == true) return false;
        if (data['isFakeDriver'] == true) return false;
        return data['approvalStatus'] == 'approved';
      }).length;
    }

    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .get();
    return snapshot.docs.where((doc) => doc.data()['isBlocked'] != true).length;
  }
}

class BroadcastResult {
  const BroadcastResult({
    required this.sent,
    required this.total,
    required this.audience,
    this.usedFirestore = false,
  });

  final int sent;
  final int total;
  final String audience;
  final bool usedFirestore;
}
