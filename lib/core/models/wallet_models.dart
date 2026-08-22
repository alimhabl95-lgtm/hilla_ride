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
  withdrawal,
}

enum WalletLedgerStatus {
  posted,
  pending,
  reversed,
}

extension WalletLedgerStatusX on WalletLedgerStatus {
  String get value => name;

  static WalletLedgerStatus fromString(String? raw) {
    return WalletLedgerStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WalletLedgerStatus.posted,
    );
  }
}

enum WalletWithdrawalStatus {
  pending,
  approved,
  processing,
  completed,
  rejected,
  cancelled,
}

extension WalletWithdrawalStatusX on WalletWithdrawalStatus {
  String get value => name;

  static WalletWithdrawalStatus fromString(String? raw) {
    return WalletWithdrawalStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => WalletWithdrawalStatus.pending,
    );
  }
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
    this.minWithdrawalIqd = 5000,
    this.maxWithdrawalIqd = 0,
    this.withdrawalsEnabled = true,
    /// Auto-credited to driver wallet on approve. 0 disables.
    this.registrationBonusIqd = 0,
    this.companySuperQiNumber = '',
    this.companySuperQiName = 'Hello Tuk-Tuk',
    /// WhatsApp number drivers use to send SuperQi / payment receipts.
    this.managerWhatsappNumber = '',
    this.rechargeInstructionsEn =
        'Transfer the amount to the company SuperQi number, then submit your receipt for verification.',
    this.rechargeInstructionsAr =
        'حوّل المبلغ إلى رقم سوبر كي الخاص بالشركة، ثم أرسل إيصال الدفع للمراجعة.',
    this.enabledMethods = const ['superQi', 'cash', 'bankTransfer'],
  });

  final int minBalanceIqd;
  final int lowBalanceWarningIqd;
  final int minWithdrawalIqd;
  /// 0 means no maximum.
  final int maxWithdrawalIqd;
  final bool withdrawalsEnabled;
  final int registrationBonusIqd;
  final String companySuperQiNumber;
  final String companySuperQiName;
  final String managerWhatsappNumber;
  final String rechargeInstructionsEn;
  final String rechargeInstructionsAr;
  final List<String> enabledMethods;

  factory WalletConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const WalletConfig();
    return WalletConfig(
      minBalanceIqd: (data['minBalanceIqd'] as num?)?.toInt() ?? 1,
      lowBalanceWarningIqd:
          (data['lowBalanceWarningIqd'] as num?)?.toInt() ?? 5000,
      minWithdrawalIqd: (data['minWithdrawalIqd'] as num?)?.toInt() ?? 5000,
      maxWithdrawalIqd: (data['maxWithdrawalIqd'] as num?)?.toInt() ?? 0,
      withdrawalsEnabled: data['withdrawalsEnabled'] as bool? ?? true,
      registrationBonusIqd:
          (data['registrationBonusIqd'] as num?)?.toInt() ?? 0,
      companySuperQiNumber: data['companySuperQiNumber'] as String? ?? '',
      companySuperQiName:
          data['companySuperQiName'] as String? ?? 'Hello Tuk-Tuk',
      managerWhatsappNumber: data['managerWhatsappNumber'] as String? ?? '',
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
        'minWithdrawalIqd': minWithdrawalIqd,
        'maxWithdrawalIqd': maxWithdrawalIqd,
        'withdrawalsEnabled': withdrawalsEnabled,
        'registrationBonusIqd': registrationBonusIqd,
        'companySuperQiNumber': companySuperQiNumber,
        'companySuperQiName': companySuperQiName,
        'managerWhatsappNumber': managerWhatsappNumber,
        'rechargeInstructionsEn': rechargeInstructionsEn,
        'rechargeInstructionsAr': rechargeInstructionsAr,
        'enabledMethods': enabledMethods,
      };

  /// Digits only for `wa.me/{digits}`.
  String get managerWhatsappDigits =>
      managerWhatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');

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
    this.withdrawalRequestId = '',
    this.referenceId = '',
    this.status = WalletLedgerStatus.posted,
    this.createdBy = '',
    this.note = '',
    this.description = '',
    this.createdAt,
  });

  final String id;
  final String driverId;
  final WalletLedgerType type;
  final int amountIqd;
  final int balanceAfterIqd;
  final String rideId;
  final String rechargeRequestId;
  final String withdrawalRequestId;
  final String referenceId;
  final WalletLedgerStatus status;
  final String createdBy;
  final String note;
  final String description;
  final DateTime? createdAt;

  String get displayDescription =>
      description.isNotEmpty ? description : note;

  factory WalletLedgerEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rideId = data['rideId'] as String? ?? '';
    final rechargeRequestId = data['rechargeRequestId'] as String? ?? '';
    final withdrawalRequestId = data['withdrawalRequestId'] as String? ?? '';
    final rewardGrantId = data['rewardGrantId'] as String? ?? '';
    final referenceId = (data['referenceId'] as String? ?? '').isNotEmpty
        ? data['referenceId'] as String
        : (withdrawalRequestId.isNotEmpty
            ? withdrawalRequestId
            : (rechargeRequestId.isNotEmpty
                ? rechargeRequestId
                : (rideId.isNotEmpty
                    ? rideId
                    : rewardGrantId)));
    return WalletLedgerEntry(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      type: WalletLedgerTypeX.fromString(data['type'] as String?),
      amountIqd: (data['amountIqd'] as num?)?.toInt() ?? 0,
      balanceAfterIqd: (data['balanceAfterIqd'] as num?)?.toInt() ?? 0,
      rideId: rideId,
      rechargeRequestId: rechargeRequestId,
      withdrawalRequestId: withdrawalRequestId,
      referenceId: referenceId,
      status: WalletLedgerStatusX.fromString(data['status'] as String?),
      createdBy: data['createdBy'] as String? ?? '',
      note: data['note'] as String? ?? '',
      description: data['description'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class WalletWithdrawalRequest {
  const WalletWithdrawalRequest({
    required this.id,
    required this.driverId,
    required this.amountIqd,
    required this.status,
    this.cardholderName = '',
    this.cardLast4 = '',
    this.cardBrand = 'mastercard',
    this.driverName = '',
    this.driverPhone = '',
    this.districtId = '',
    this.subDistrictId = '',
    this.adminNote = '',
    this.rejectionReason = '',
    this.referenceId = '',
    this.ledgerEntryId = '',
    this.reviewedBy = '',
    this.processedBy = '',
    this.reviewedAt,
    this.processedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String driverId;
  final int amountIqd;
  final WalletWithdrawalStatus status;
  final String cardholderName;
  final String cardLast4;
  final String cardBrand;
  final String driverName;
  final String driverPhone;
  final String districtId;
  final String subDistrictId;
  final String adminNote;
  final String rejectionReason;
  final String referenceId;
  final String ledgerEntryId;
  final String reviewedBy;
  final String processedBy;
  final DateTime? reviewedAt;
  final DateTime? processedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOpen =>
      status == WalletWithdrawalStatus.pending ||
      status == WalletWithdrawalStatus.approved ||
      status == WalletWithdrawalStatus.processing;

  factory WalletWithdrawalRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return WalletWithdrawalRequest(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      amountIqd: (data['amountIqd'] as num?)?.toInt() ?? 0,
      status: WalletWithdrawalStatusX.fromString(data['status'] as String?),
      cardholderName: data['cardholderName'] as String? ?? '',
      cardLast4: data['cardLast4'] as String? ?? '',
      cardBrand: data['cardBrand'] as String? ?? 'mastercard',
      driverName: data['driverName'] as String? ?? '',
      driverPhone: data['driverPhone'] as String? ?? '',
      districtId: data['districtId'] as String? ?? '',
      subDistrictId: data['subDistrictId'] as String? ?? '',
      adminNote: data['adminNote'] as String? ?? '',
      rejectionReason: data['rejectionReason'] as String? ?? '',
      referenceId: data['referenceId'] as String? ?? '',
      ledgerEntryId: data['ledgerEntryId'] as String? ?? '',
      reviewedBy: data['reviewedBy'] as String? ?? '',
      processedBy: data['processedBy'] as String? ?? '',
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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
    this.districtId = '',
    this.subDistrictId = '',
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
  final String districtId;
  final String subDistrictId;
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
      districtId: data['districtId'] as String? ?? '',
      subDistrictId: data['subDistrictId'] as String? ?? '',
      reviewedBy: data['reviewedBy'] as String? ?? '',
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
