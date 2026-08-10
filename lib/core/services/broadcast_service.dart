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
    String? provinceId,
    String? districtId,
    String? subDistrictId,
    String? targetUserId,
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
        provinceId: provinceId,
        districtId: districtId,
        subDistrictId: subDistrictId,
        targetUserId: targetUserId,
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
        provinceId: provinceId,
        districtId: districtId,
        subDistrictId: subDistrictId,
        targetUserId: targetUserId,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('sendBroadcast failed: $error, using Firestore.');
      }
      return _sendViaFirestore(
        audience: audience,
        title: trimmedTitle,
        message: trimmedMessage,
        provinceId: provinceId,
        districtId: districtId,
        subDistrictId: subDistrictId,
        targetUserId: targetUserId,
      );
    }
  }

  Future<BroadcastResult> _sendViaCloudFunction({
    required String audience,
    required String title,
    required String message,
    String? provinceId,
    String? districtId,
    String? subDistrictId,
    String? targetUserId,
  }) async {
    final callable = _functions.httpsCallable('sendBroadcast');
    final payload = <String, dynamic>{
      'audience': audience,
      'title': title,
      'message': message,
      if (provinceId != null && provinceId.isNotEmpty) 'provinceId': provinceId,
      if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
      if (subDistrictId != null && subDistrictId.isNotEmpty)
        'subDistrictId': subDistrictId,
      if (targetUserId != null && targetUserId.isNotEmpty)
        'targetUserId': targetUserId,
    };
    final result = await callable.call(payload);
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
    String? provinceId,
    String? districtId,
    String? subDistrictId,
    String? targetUserId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Sign in required.');
    }

    final total = await _countAudience(
      audience,
      provinceId: provinceId,
      districtId: districtId,
      subDistrictId: subDistrictId,
      targetUserId: targetUserId,
    );

    await _firestore.collection('announcements').add({
      'audience': audience,
      'title': title,
      'body': message,
      'sentCount': total,
      'totalTokens': total,
      'delivery': 'firestore',
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      if (provinceId != null && provinceId.isNotEmpty) 'provinceId': provinceId,
      if (districtId != null && districtId.isNotEmpty) 'districtId': districtId,
      if (subDistrictId != null && subDistrictId.isNotEmpty)
        'subDistrictId': subDistrictId,
      if (targetUserId != null && targetUserId.isNotEmpty)
        'targetUserId': targetUserId,
    });

    return BroadcastResult(
      sent: total,
      total: total,
      audience: audience,
      usedFirestore: true,
    );
  }

  Future<int> _countAudience(
    String audience, {
    String? provinceId,
    String? districtId,
    String? subDistrictId,
    String? targetUserId,
  }) async {
    if (targetUserId != null && targetUserId.isNotEmpty) return 1;

    if (audience == 'businesses') {
      final snapshot = await _firestore
          .collection('businesses')
          .where('status', isEqualTo: 'live')
          .get();
      return snapshot.docs.length;
    }

    if (audience == 'allDrivers' || audience == 'drivers') {
      final snapshot = await _firestore.collection('drivers').get();
      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['isBlocked'] == true || data['isRemoved'] == true) return false;
        if (data['isFakeDriver'] == true) return false;
        if (data['approvalStatus'] != 'approved') return false;
        if (districtId != null &&
            districtId.isNotEmpty &&
            data['assignedDistrictId'] != districtId) {
          return false;
        }
        if (subDistrictId != null &&
            subDistrictId.isNotEmpty &&
            data['assignedSubDistrictId'] != subDistrictId) {
          return false;
        }
        return true;
      }).length;
    }

    if (audience == 'allCustomers' ||
        audience == 'customers' ||
        audience == 'province' ||
        audience == 'district' ||
        audience == 'subDistrict') {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .get();
      return snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['isBlocked'] == true) return false;
        if (districtId != null &&
            districtId.isNotEmpty &&
            data['districtId'] != districtId) {
          return false;
        }
        if (subDistrictId != null &&
            subDistrictId.isNotEmpty &&
            data['subDistrictId'] != subDistrictId) {
          return false;
        }
        if (provinceId != null &&
            provinceId.isNotEmpty &&
            data['provinceId'] != provinceId) {
          return false;
        }
        return true;
      }).length;
    }

    return 0;
  }

  Stream<List<AnnouncementRecord>> watchRecentAnnouncements({int limit = 40}) {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AnnouncementRecord.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}

class AnnouncementRecord {
  const AnnouncementRecord({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    this.sentCount = 0,
    this.createdAt,
    this.provinceId,
    this.districtId,
    this.subDistrictId,
    this.targetUserId,
  });

  final String id;
  final String audience;
  final String title;
  final String body;
  final int sentCount;
  final DateTime? createdAt;
  final String? provinceId;
  final String? districtId;
  final String? subDistrictId;
  final String? targetUserId;

  factory AnnouncementRecord.fromMap(String id, Map<String, dynamic> data) {
    return AnnouncementRecord(
      id: id,
      audience: data['audience'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      sentCount: (data['sentCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      provinceId: data['provinceId'] as String?,
      districtId: data['districtId'] as String?,
      subDistrictId: data['subDistrictId'] as String?,
      targetUserId: data['targetUserId'] as String?,
    );
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
