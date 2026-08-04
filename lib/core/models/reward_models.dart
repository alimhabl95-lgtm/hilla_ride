import 'package:cloud_firestore/cloud_firestore.dart';

enum RewardCampaignStatus {
  draft,
  active,
  paused,
  ended,
  deleted,
}

extension RewardCampaignStatusX on RewardCampaignStatus {
  String get value => name;

  static RewardCampaignStatus fromString(String? raw) {
    return RewardCampaignStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RewardCampaignStatus.draft,
    );
  }
}

enum RewardConditionType {
  completedTrips,
  totalEarnings,
  onlineHours,
  rating,
  acceptanceRate,
  cancellationRate,
  custom,
}

extension RewardConditionTypeX on RewardConditionType {
  String get value => name;

  static RewardConditionType fromString(String? raw) {
    return RewardConditionType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => RewardConditionType.completedTrips,
    );
  }
}

enum RewardType {
  walletCredit,
  bonus,
  commissionDiscount,
  freeTrips,
  custom,
}

extension RewardTypeX on RewardType {
  String get value => switch (this) {
        RewardType.walletCredit => 'wallet_credit',
        RewardType.bonus => 'bonus',
        RewardType.commissionDiscount => 'commission_discount',
        RewardType.freeTrips => 'free_trips',
        RewardType.custom => 'custom',
      };

  static RewardType fromString(String? raw) {
    switch (raw) {
      case 'bonus':
        return RewardType.bonus;
      case 'commission_discount':
        return RewardType.commissionDiscount;
      case 'free_trips':
        return RewardType.freeTrips;
      case 'custom':
        return RewardType.custom;
      default:
        return RewardType.walletCredit;
    }
  }
}

class RewardCondition {
  const RewardCondition({
    required this.type,
    this.op = 'gte',
    required this.value,
    this.scope = 'campaign',
    this.customKey = '',
  });

  final RewardConditionType type;
  final String op;
  final num value;
  final String scope;
  final String customKey;

  factory RewardCondition.fromMap(Map<String, dynamic> data) {
    return RewardCondition(
      type: RewardConditionTypeX.fromString(data['type'] as String?),
      op: data['op'] as String? ?? 'gte',
      value: (data['value'] as num?) ?? 0,
      scope: data['scope'] as String? ?? 'campaign',
      customKey: data['customKey'] as String? ?? data['key'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'op': op,
        'value': value,
        'scope': scope,
        if (customKey.isNotEmpty) 'customKey': customKey,
      };
}

class RewardPayload {
  const RewardPayload({
    required this.type,
    this.amountIqd = 0,
    this.commissionDiscountPercent = 0,
    this.freeTripsCount = 0,
    this.durationDays = 0,
    this.customPayload = const {},
  });

  final RewardType type;
  final int amountIqd;
  final double commissionDiscountPercent;
  final int freeTripsCount;
  final int durationDays;
  final Map<String, dynamic> customPayload;

  factory RewardPayload.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return RewardPayload(
      type: RewardTypeX.fromString(map['type'] as String?),
      amountIqd: (map['amountIqd'] as num?)?.toInt() ?? 0,
      commissionDiscountPercent:
          (map['commissionDiscountPercent'] as num?)?.toDouble() ?? 0,
      freeTripsCount: (map['freeTripsCount'] as num?)?.toInt() ?? 0,
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 0,
      customPayload: Map<String, dynamic>.from(
        (map['customPayload'] as Map?) ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type.value,
        'amountIqd': amountIqd,
        'commissionDiscountPercent': commissionDiscountPercent,
        'freeTripsCount': freeTripsCount,
        'durationDays': durationDays,
        'customPayload': customPayload,
      };
}

class RewardCampaign {
  const RewardCampaign({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    this.descriptionEn = '',
    this.descriptionAr = '',
    required this.status,
    this.conditionLogic = 'and',
    this.conditions = const [],
    required this.reward,
    this.maxGrantsPerDriver = 1,
    this.maxTotalGrants,
    this.cooldownHours = 0,
    this.startAt,
    this.endAt,
    this.priority = 0,
    this.notifyOnGrant = true,
    this.totalGrantedCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final RewardCampaignStatus status;
  final String conditionLogic;
  final List<RewardCondition> conditions;
  final RewardPayload reward;
  final int maxGrantsPerDriver;
  final int? maxTotalGrants;
  final int cooldownHours;
  final DateTime? startAt;
  final DateTime? endAt;
  final int priority;
  final bool notifyOnGrant;
  final int totalGrantedCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == RewardCampaignStatus.active;

  String titleForLocale(bool isAr) => isAr ? titleAr : titleEn;

  String descriptionForLocale(bool isAr) =>
      isAr ? descriptionAr : descriptionEn;

  factory RewardCampaign.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final conditionsRaw = data['conditions'] as List<dynamic>? ?? const [];
    return RewardCampaign(
      id: doc.id,
      titleEn: data['titleEn'] as String? ?? '',
      titleAr: data['titleAr'] as String? ?? '',
      descriptionEn: data['descriptionEn'] as String? ?? '',
      descriptionAr: data['descriptionAr'] as String? ?? '',
      status: RewardCampaignStatusX.fromString(data['status'] as String?),
      conditionLogic: data['conditionLogic'] as String? ?? 'and',
      conditions: conditionsRaw
          .whereType<Map>()
          .map((e) => RewardCondition.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      reward: RewardPayload.fromMap(
        data['reward'] is Map
            ? Map<String, dynamic>.from(data['reward'] as Map)
            : null,
      ),
      maxGrantsPerDriver: (data['maxGrantsPerDriver'] as num?)?.toInt() ?? 1,
      maxTotalGrants: (data['maxTotalGrants'] as num?)?.toInt(),
      cooldownHours: (data['cooldownHours'] as num?)?.toInt() ?? 0,
      startAt: (data['startAt'] as Timestamp?)?.toDate(),
      endAt: (data['endAt'] as Timestamp?)?.toDate(),
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      notifyOnGrant: data['notifyOnGrant'] as bool? ?? true,
      totalGrantedCount: (data['totalGrantedCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCallablePayload({String? id}) => {
        if (id != null) 'id': id,
        'titleEn': titleEn,
        'titleAr': titleAr,
        'descriptionEn': descriptionEn,
        'descriptionAr': descriptionAr,
        'status': status.value,
        'conditionLogic': conditionLogic,
        'conditions': conditions.map((c) => c.toMap()).toList(),
        'reward': reward.toMap(),
        'maxGrantsPerDriver': maxGrantsPerDriver,
        'maxTotalGrants': maxTotalGrants,
        'cooldownHours': cooldownHours,
        'startAt': startAt?.toUtc().toIso8601String(),
        'endAt': endAt?.toUtc().toIso8601String(),
        'priority': priority,
        'notifyOnGrant': notifyOnGrant,
      };
}

class RewardGrant {
  const RewardGrant({
    required this.id,
    required this.campaignId,
    required this.driverId,
    required this.rewardType,
    this.campaignTitleEn = '',
    this.campaignTitleAr = '',
    this.amountIqd = 0,
    this.createdAt,
  });

  final String id;
  final String campaignId;
  final String driverId;
  final String rewardType;
  final String campaignTitleEn;
  final String campaignTitleAr;
  final int amountIqd;
  final DateTime? createdAt;

  String titleForLocale(bool isAr) =>
      isAr ? campaignTitleAr : campaignTitleEn;

  factory RewardGrant.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RewardGrant(
      id: doc.id,
      campaignId: data['campaignId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      rewardType: data['rewardType'] as String? ?? '',
      campaignTitleEn: data['campaignTitleEn'] as String? ?? '',
      campaignTitleAr: data['campaignTitleAr'] as String? ?? '',
      amountIqd: (data['amountIqd'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RewardProgress {
  const RewardProgress({
    required this.id,
    required this.campaignId,
    required this.driverId,
    this.completedTrips = 0,
    this.totalEarningsIqd = 0,
    this.onlineSeconds = 0,
    this.grantsCount = 0,
    this.lastGrantAt,
  });

  final String id;
  final String campaignId;
  final String driverId;
  final int completedTrips;
  final int totalEarningsIqd;
  final int onlineSeconds;
  final int grantsCount;
  final DateTime? lastGrantAt;

  factory RewardProgress.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RewardProgress(
      id: doc.id,
      campaignId: data['campaignId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      completedTrips: (data['completedTrips'] as num?)?.toInt() ?? 0,
      totalEarningsIqd: (data['totalEarningsIqd'] as num?)?.toInt() ?? 0,
      onlineSeconds: (data['onlineSeconds'] as num?)?.toInt() ?? 0,
      grantsCount: (data['grantsCount'] as num?)?.toInt() ?? 0,
      lastGrantAt: (data['lastGrantAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RewardAuditLog {
  const RewardAuditLog({
    required this.id,
    required this.action,
    this.actorUid = '',
    this.campaignId = '',
    this.driverId = '',
    this.grantId = '',
    this.details = const {},
    this.createdAt,
  });

  final String id;
  final String action;
  final String actorUid;
  final String campaignId;
  final String driverId;
  final String grantId;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  factory RewardAuditLog.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RewardAuditLog(
      id: doc.id,
      action: data['action'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      campaignId: data['campaignId'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      grantId: data['grantId'] as String? ?? '',
      details: Map<String, dynamic>.from(
        (data['details'] as Map?) ?? const {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
