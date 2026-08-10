import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.details = '',
    this.createdAt,
    this.ipAddress,
  });

  final String id;
  final String adminId;
  final String adminName;
  final String action;
  final String entityType;
  final String entityId;
  final String details;
  final DateTime? createdAt;
  final String? ipAddress;

  factory AdminAuditLog.fromMap(String id, Map<String, dynamic> data) {
    return AdminAuditLog(
      id: id,
      adminId: data['adminId'] as String? ?? '',
      adminName: data['adminName'] as String? ?? '',
      action: data['action'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      details: data['details'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      ipAddress: data['ipAddress'] as String?,
    );
  }
}

/// Reads audit entries written by Cloud Functions — no local writes.
class AdminAuditService {
  AdminAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AdminAuditLog>> watchRecent({int limit = 200}) {
    return _firestore
        .collection('adminAuditLogs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminAuditLog.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
