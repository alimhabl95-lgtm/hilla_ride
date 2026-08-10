import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ReferralService {
  ReferralService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final _random = Random();

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<String?> watchReferralCode(String uid) {
    return _userRef(uid).snapshots().map(
          (snap) => snap.data()?['referralCode'] as String?,
        );
  }

  Future<String> ensureReferralCode(String uid) async {
    final doc = await _userRef(uid).get();
    final existing = doc.data()?['referralCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateCode();
      final collision = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      if (collision.docs.isNotEmpty) continue;

      await _userRef(uid).set(
        {'referralCode': code},
        SetOptions(merge: true),
      );
      return code;
    }

    throw StateError('Could not generate a unique referral code.');
  }

  Future<void> applyReferralCode({
    required String code,
  }) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) return;

    final callable = _functions.httpsCallable('applyReferralCode');
    await callable.call({'referralCode': trimmed});
  }

  String _generateCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer('HT');
    for (var i = 0; i < 6; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}
