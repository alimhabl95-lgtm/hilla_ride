import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletStatus {
  active,
  low,
  blocked,
}

extension WalletStatusX on WalletStatus {
  String get value => name;

  static WalletStatus fromString(String? raw) {
    switch (raw) {
      case 'low':
        return WalletStatus.low;
      case 'blocked':
        return WalletStatus.blocked;
      default:
        return WalletStatus.active;
    }
  }
}

enum WalletLedgerType {
  recharge,
  commission,
  adjustment,
  refund,
  bonus,
  penalty,
  reward,
}

extension WalletLedgerTypeX on WalletLedgerType {
  String get value => name;

  static WalletLedgerType fromString(String? raw) {
    return WalletLedgerType.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WalletLedgerType.adjustment,
    );
  }
}

enum WalletRechargeMethod {
  superQi,
  cash,
  bankTransfer,
  gateway,
}

extension WalletRechargeMethodX on WalletRechargeMethod {
  String get value => name;

  static WalletRechargeMethod fromString(String? raw) {
    return WalletRechargeMethod.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WalletRechargeMethod.superQi,
    );
  }
}

enum WalletRechargeStatus {
  pending,
  approved,
  rejected,
}

extension WalletRechargeStatusX on WalletRechargeStatus {
  String get value => name;

  static WalletRechargeStatus fromString(String? raw) {
    return WalletRechargeStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WalletRechargeStatus.pending,
    );
  }
}

class WalletConfig {
  const WalletConfig({
    /// Managers can raise this in Admin → Wallet. Balance must also be > 0.
    this.minBalanceIqd = 1,
    this.lowBalanceWarningIqd = 5000,
    this.companySuperQiNumber = '',
    this.companySuperQiName = 'Hello Tuk-Tuk',
    this.rechargeInstructionsEn =
        'Transfer the amount to the company SuperQi number, then submit your receipt for verification.',
    this.rechargeInstructionsAr =
        'حوّل المبلغ إلى رقم سوبر كي الخاص بالشركة، ثم أرسل إيصال الدفع للمراجعة.',
    this.enabledMethods = const ['superQi', 'cash', 'bankTransfer'],
  });

  final int minBalanceIqd;
  final int lowBalanceWarningIqd;
  final String companySuperQiNumber;
  final String companySuperQiName;
  final String rechargeInstructionsEn;
  final String rechargeInstructionsAr;
  final List<String> enabledMethods;

  factory WalletConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const WalletConfig();
    return WalletConfig(
      minBalanceIqd: (data['minBalanceIqd'] as num?)?.toInt() ?? 1,
      lowBalanceWarningIqd:
          (data['lowBalanceWarningIqd'] as num?)?.toInt() ?? 5000,
      companySuperQiNumber: data['companySuperQiNumber'] as String? ?? '',
      companySuperQiName:
          data['companySuperQiName'] as String? ?? 'Hello Tuk-Tuk',
      rechargeInstructionsEn: data['rechargeInstructionsEn'] as String? ??
          'Transfer the amount to the company SuperQi number, then submit your receipt for verification.',
      rechargeInstructionsAr: data['rechargeInstructionsAr'] as String? ??
          'حوّل المبلغ إلى رقم سوبر كي الخاص بالشركة، ثم أرسل إيصال الدفع للمراجعة.',
      enabledMethods: (data['enabledMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['superQi', 'cash', 'bankTransfer'],
    );
  }

  Map<String, dynamic> toMap() => {
        'minBalanceIqd': minBalanceIqd,
        'lowBalanceWarningIqd': lowBalanceWarningIqd,
        'companySuperQiNumber': companySuperQiNumber,
        'companySuperQiName': companySuperQiName,
        'rechargeInstructionsEn': rechargeInstructionsEn,
        'rechargeInstructionsAr': rechargeInstructionsAr,
        'enabledMethods': enabledMethods,
      };

  String instructionsForLocale(String locale) =>
      locale.startsWith('ar') ? rechargeInstructionsAr : rechargeInstructionsEn;
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.driverId,
    required this.type,
    required this.amountIqd,
    required this.balanceAfterIqd,
    this.rideId = '',
    this.rechargeRequestId = '',
    this.createdBy = '',
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String driverId;
  final WalletLedgerType type;
  final int amountIqd;
  final int balanceAfterIqd;
  final String rideId;
  final String rechargeRequestId;
  final String createdBy;
  final String note;
  final DateTime? createdAt;

  factory WalletLedgerEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WalletLedgerEntry(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      type: WalletLedgerTypeX.fromString(data['type'] as String?),
      amountIqd: (data['amountIqd'] as num?)?.toInt() ?? 0,
      balanceAfterIqd: (data['balanceAfterIqd'] as num?)?.toInt() ?? 0,
      rideId: data['rideId'] as String? ?? '',
      rechargeRequestId: data['rechargeRequestId'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      note: data['note'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class WalletRechargeRequest {
  const WalletRechargeRequest({
    required this.id,
    required this.driverId,
    required this.method,
    required this.amountIqd,
    required this.status,
    this.referenceNumber = '',
    this.notes = '',
    this.screenshotUrl = '',
    this.driverName = '',
    this.driverPhone = '',
    this.reviewedBy = '',
    this.reviewedAt,
    this.rejectionReason = '',
    this.createdAt,
  });

  final String id;
  final String driverId;
  final WalletRechargeMethod method;
  final int amountIqd;
  final WalletRechargeStatus status;
  final String referenceNumber;
  final String notes;
  final String screenshotUrl;
  final String driverName;
  final String driverPhone;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final String rejectionReason;
  final DateTime? createdAt;

  factory WalletRechargeRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WalletRechargeRequest(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      method: WalletRechargeMethodX.fromString(data['method'] as String?),
      amountIqd: (data['amountIqd'] as num?)?.toInt() ?? 0,
      status: WalletRechargeStatusX.fromString(data['status'] as String?),
      referenceNumber: data['referenceNumber'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      screenshotUrl: data['screenshotUrl'] as String? ?? '',
      driverName: data['driverName'] as String? ?? '',
      driverPhone: data['driverPhone'] as String? ?? '',
      reviewedBy: data['reviewedBy'] as String? ?? '',
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
