import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/complaint_models.dart';
import 'package:hilla_ride/core/services/admin_service.dart';
import 'package:hilla_ride/core/services/app_services.dart';

class ComplaintService {
  ComplaintService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  Stream<List<Complaint>> watchAll({int limit = 500}) {
    return _firestore
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Complaint.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> createComplaint({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String body,
    String provinceId = '',
    String districtId = '',
    String subDistrictId = '',
    String? relatedRideId,
    String targetUserId = '',
    String targetRole = '',
    String targetName = '',
    String category = '',
  }) async {
    try {
      final callable = _functions.httpsCallable('createComplaint');
      final result = await callable.call({
        'userId': userId,
        'userRole': userRole,
        'userName': userName,
        'subject': subject.trim(),
        'body': body.trim(),
        if (provinceId.isNotEmpty) 'provinceId': provinceId,
        if (districtId.isNotEmpty) 'districtId': districtId,
        if (subDistrictId.isNotEmpty) 'subDistrictId': subDistrictId,
        if (relatedRideId != null && relatedRideId.isNotEmpty)
          'relatedRideId': relatedRideId,
        if (targetUserId.isNotEmpty) 'targetUserId': targetUserId,
        if (targetRole.isNotEmpty) 'targetRole': targetRole,
        if (targetName.isNotEmpty) 'targetName': targetName,
        if (category.isNotEmpty) 'category': category,
      });
      final data = Map<String, dynamic>.from(result.data as Map? ?? {});
      return data['complaintId'] as String? ?? '';
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint('createComplaint callable unavailable (${error.code}).');
      }
      rethrow;
    }
  }

  Future<String> createComplaintDirect({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String body,
    String provinceId = '',
    String districtId = '',
    String subDistrictId = '',
    String? relatedRideId,
    String targetUserId = '',
    String targetRole = '',
    String targetName = '',
    String category = '',
  }) async {
    final ref = _firestore.collection('complaints').doc();
    await ref.set({
      'userId': userId,
      'userRole': userRole,
      'userName': userName,
      'subject': subject.trim(),
      'body': body.trim(),
      'status': ComplaintStatus.open.value,
      'adminReply': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (provinceId.isNotEmpty) 'provinceId': provinceId,
      if (districtId.isNotEmpty) 'districtId': districtId,
      if (subDistrictId.isNotEmpty) 'subDistrictId': subDistrictId,
      if (relatedRideId != null && relatedRideId.isNotEmpty)
        'relatedRideId': relatedRideId,
      if (targetUserId.isNotEmpty) 'targetUserId': targetUserId,
      if (targetRole.isNotEmpty) 'targetRole': targetRole,
      if (targetName.isNotEmpty) 'targetName': targetName,
      if (category.isNotEmpty) 'category': category,
      'createdBy': _auth.currentUser?.uid,
    });
    return ref.id;
  }

  Future<void> updateStatus({
    required String complaintId,
    required ComplaintStatus status,
  }) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reply({
    required String complaintId,
    required String adminReply,
    ComplaintStatus? status,
  }) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'adminReply': adminReply.trim(),
      'status': (status ?? ComplaintStatus.inProgress).value,
      'updatedAt': FieldValue.serverTimestamp(),
      'repliedAt': FieldValue.serverTimestamp(),
      'repliedBy': _auth.currentUser?.uid,
    });
  }

  Future<void> close({required String complaintId}) async {
    await updateStatus(
      complaintId: complaintId,
      status: ComplaintStatus.closed,
    );
  }

  Future<void> banUser({
    required AdminService adminService,
    required DriverService driverService,
    required String userId,
    required String userRole,
  }) async {
    final role = userRole.toLowerCase();
    if (role == 'driver') {
      await driverService.setDriverBlocked(
        driverId: userId,
        blocked: true,
      );
      return;
    }
    await adminService.setCustomerBlocked(
      userId: userId,
      blocked: true,
    );
  }
}
