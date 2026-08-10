enum ComplaintStatus {
  open,
  inProgress,
  resolved,
  closed,
}

extension ComplaintStatusX on ComplaintStatus {
  String get value => name;

  static ComplaintStatus fromString(String? raw) {
    return ComplaintStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ComplaintStatus.open,
    );
  }
}

class Complaint {
  const Complaint({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.subject,
    required this.body,
    required this.status,
    this.adminReply = '',
    this.createdAt,
    this.updatedAt,
    this.provinceId = '',
    this.districtId = '',
    this.subDistrictId = '',
    this.relatedRideId,
    this.targetUserId = '',
    this.targetRole = '',
    this.targetName = '',
    this.category = '',
  });

  final String id;
  final String userId;
  final String userRole;
  final String userName;
  final String subject;
  final String body;
  final ComplaintStatus status;
  final String adminReply;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String provinceId;
  final String districtId;
  final String subDistrictId;
  final String? relatedRideId;
  final String targetUserId;
  final String targetRole;
  final String targetName;
  final String category;

  bool get isOpen =>
      status == ComplaintStatus.open || status == ComplaintStatus.inProgress;

  bool get hasTarget =>
      targetUserId.isNotEmpty ||
      targetName.isNotEmpty ||
      targetRole.isNotEmpty;

  factory Complaint.fromMap(String id, Map<String, dynamic> data) {
    return Complaint(
      id: id,
      userId: data['userId'] as String? ?? '',
      userRole: data['userRole'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      body: data['body'] as String? ?? '',
      status: ComplaintStatusX.fromString(data['status'] as String?),
      adminReply: data['adminReply'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() as DateTime?,
      provinceId: data['provinceId'] as String? ?? '',
      districtId: data['districtId'] as String? ?? '',
      subDistrictId: data['subDistrictId'] as String? ?? '',
      relatedRideId: data['relatedRideId'] as String?,
      targetUserId: data['targetUserId'] as String? ?? '',
      targetRole: data['targetRole'] as String? ?? '',
      targetName: data['targetName'] as String? ?? '',
      category: data['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userRole': userRole,
      'userName': userName,
      'subject': subject,
      'body': body,
      'status': status.value,
      if (adminReply.isNotEmpty) 'adminReply': adminReply,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (provinceId.isNotEmpty) 'provinceId': provinceId,
      if (districtId.isNotEmpty) 'districtId': districtId,
      if (subDistrictId.isNotEmpty) 'subDistrictId': subDistrictId,
      if (relatedRideId != null && relatedRideId!.isNotEmpty)
        'relatedRideId': relatedRideId,
      if (targetUserId.isNotEmpty) 'targetUserId': targetUserId,
      if (targetRole.isNotEmpty) 'targetRole': targetRole,
      if (targetName.isNotEmpty) 'targetName': targetName,
      if (category.isNotEmpty) 'category': category,
    };
  }
}
