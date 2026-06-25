enum UserRole { customer, driver, manager, assistant }

extension UserRoleX on UserRole {
  String get value => name;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.customer,
    );
  }
}

enum DriverApprovalStatus { pending, approved, rejected }

enum PaymentMethod { cash }

extension PaymentMethodX on PaymentMethod {
  String get value => name;

  static PaymentMethod fromString(String? value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

extension DriverApprovalStatusX on DriverApprovalStatus {
  String get value => name;

  static DriverApprovalStatus fromString(String? value) {
    return DriverApprovalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DriverApprovalStatus.pending,
    );
  }
}

enum RideStatus {
  searching,
  matched,
  accepted,
  inProgress,
  awaitingCashPayment,
  completed,
  cancelled,
}

extension RideStatusX on RideStatus {
  String get value => name;

  static RideStatus fromString(String? value) {
    return RideStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => RideStatus.searching,
    );
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.phone,
    required this.role,
    required this.name,
    required this.age,
    this.email,
    this.gender,
    this.createdAt,
    this.isBlocked = false,
    this.cancelledRidesCount = 0,
    this.permissions = const [],
    this.createdBy,
    this.promoCode = '',
    this.promoRidesUsed = 0,
    this.promoRidesLimit = 0,
    this.profilePhotoUrl = '',
  });

  final String uid;
  final String phone;
  final UserRole role;
  final String name;
  final int age;
  final String? email;
  final String? gender;
  final DateTime? createdAt;
  final bool isBlocked;
  final int cancelledRidesCount;
  final List<String> permissions;
  final String? createdBy;
  final String promoCode;
  final int promoRidesUsed;
  final int promoRidesLimit;
  final String profilePhotoUrl;

  bool get hasActivePromo =>
      promoCode.isNotEmpty && promoRidesUsed < promoRidesLimit;

  bool get isProfileComplete => name.trim().isNotEmpty && age > 0;

  bool get isAdminUser =>
      role == UserRole.manager || role == UserRole.assistant;

  bool get isOwnerManager => role == UserRole.manager;

  bool hasAdminPermission(String permission) {
    if (role == UserRole.manager) return true;
    if (role == UserRole.assistant) return permissions.contains(permission);
    return false;
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      phone: data['phone'] as String? ?? '',
      role: UserRoleX.fromString(data['role'] as String?),
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      email: data['email'] as String?,
      gender: data['gender'] as String?,
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      isBlocked: data['isBlocked'] as bool? ?? false,
      cancelledRidesCount: (data['cancelledRidesCount'] as num?)?.toInt() ?? 0,
      permissions: (data['permissions'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
      createdBy: data['createdBy'] as String?,
      promoCode: data['promoCode'] as String? ?? '',
      promoRidesUsed: (data['promoRidesUsed'] as num?)?.toInt() ?? 0,
      promoRidesLimit: (data['promoRidesLimit'] as num?)?.toInt() ?? 0,
      profilePhotoUrl: data['profilePhotoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'role': role.value,
      'name': name,
      'age': age,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (gender != null) 'gender': gender,
      'createdAt': createdAt,
      'isBlocked': isBlocked,
      'cancelledRidesCount': cancelledRidesCount,
      if (permissions.isNotEmpty) 'permissions': permissions,
      if (createdBy != null) 'createdBy': createdBy,
      if (promoCode.isNotEmpty) 'promoCode': promoCode,
      'promoRidesUsed': promoRidesUsed,
      if (promoRidesLimit > 0) 'promoRidesLimit': promoRidesLimit,
      if (profilePhotoUrl.isNotEmpty) 'profilePhotoUrl': profilePhotoUrl,
    };
  }
}

class DriverProfile {
  const DriverProfile({
    required this.uid,
    required this.phone,
    required this.name,
    required this.vehicleType,
    required this.vehiclePlate,
    required this.licenseNumber,
    required this.approvalStatus,
    required this.isOnline,
    this.vehicleColor = '',
    this.rating = 5.0,
    this.ratingCount = 0,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
    this.completedRidesCount = 0,
    this.totalFareCollectedIqd = 0,
    this.totalPlatformCommissionIqd = 0,
    this.outstandingPlatformCommissionIqd = 0,
    this.totalDriverEarningsIqd = 0,
    this.pendingBonusIqd = 0,
    this.totalBonusGrantedIqd = 0,
    this.lastProfitReceivedAt,
    this.idPhotoUrl = '',
    this.profilePhotoUrl = '',
    this.termsAcceptedAt,
    this.createdAt,
    this.isBlocked = false,
    this.cancelledRidesCount = 0,
    this.isRemoved = false,
    this.monthlyRideCount = 0,
    this.monthlyMonthKey = '',
    this.isFakeDriver = false,
    this.autoAcceptRides = false,
    this.hasActiveRide = false,
    this.geohash = '',
    this.assignedDistrictId = '',
    this.assignedSubDistrictId = '',
  });

  final String uid;
  final String phone;
  final String name;
  final String vehicleType;
  final String vehiclePlate;
  final String vehicleColor;
  final String licenseNumber;
  final DriverApprovalStatus approvalStatus;
  final bool isOnline;
  final double rating;
  final int ratingCount;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;
  final int completedRidesCount;
  final int totalFareCollectedIqd;
  final int totalPlatformCommissionIqd;
  final int outstandingPlatformCommissionIqd;
  final int totalDriverEarningsIqd;
  final int pendingBonusIqd;
  final int totalBonusGrantedIqd;
  final DateTime? lastProfitReceivedAt;
  final String idPhotoUrl;
  final String profilePhotoUrl;
  final DateTime? termsAcceptedAt;
  final DateTime? createdAt;
  final bool isBlocked;
  final int cancelledRidesCount;
  final bool isRemoved;
  final int monthlyRideCount;
  final String monthlyMonthKey;
  final bool isFakeDriver;
  final bool autoAcceptRides;
  final bool hasActiveRide;
  final String geohash;
  final String assignedDistrictId;
  final String assignedSubDistrictId;

  bool get isApproved => approvalStatus == DriverApprovalStatus.approved;
  bool get canDrive => isApproved && !isBlocked && !isRemoved;
  bool get hasAssignedWorkArea =>
      assignedDistrictId.trim().isNotEmpty &&
      assignedSubDistrictId.trim().isNotEmpty;
  bool get isAvailableForRides =>
      isOnline &&
      canDrive &&
      !hasActiveRide &&
      hasAssignedWorkArea;

  int get owedPlatformCommissionIqd => outstandingPlatformCommissionIqd;

  factory DriverProfile.fromMap(String uid, Map<String, dynamic> data) {
    return DriverProfile(
      uid: uid,
      phone: data['phone'] as String? ?? '',
      name: data['name'] as String? ?? '',
      vehicleType: data['vehicleType'] as String? ?? '',
      vehiclePlate: data['vehiclePlate'] as String? ?? '',
      vehicleColor: data['vehicleColor'] as String? ?? '',
      licenseNumber: data['licenseNumber'] as String? ?? '',
      approvalStatus: DriverApprovalStatusX.fromString(
        data['approvalStatus'] as String?,
      ),
      isOnline: data['isOnline'] as bool? ?? false,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationUpdatedAt:
          (data['locationUpdatedAt'] as dynamic)?.toDate() as DateTime?,
      completedRidesCount: (data['completedRidesCount'] as num?)?.toInt() ?? 0,
      totalFareCollectedIqd:
          (data['totalFareCollectedIqd'] as num?)?.toInt() ?? 0,
      totalPlatformCommissionIqd:
          (data['totalPlatformCommissionIqd'] as num?)?.toInt() ?? 0,
      outstandingPlatformCommissionIqd: data
              .containsKey('outstandingPlatformCommissionIqd')
          ? (data['outstandingPlatformCommissionIqd'] as num?)?.toInt() ?? 0
          : (data['totalPlatformCommissionIqd'] as num?)?.toInt() ?? 0,
      totalDriverEarningsIqd:
          (data['totalDriverEarningsIqd'] as num?)?.toInt() ?? 0,
      pendingBonusIqd: (data['pendingBonusIqd'] as num?)?.toInt() ?? 0,
      totalBonusGrantedIqd:
          (data['totalBonusGrantedIqd'] as num?)?.toInt() ?? 0,
      lastProfitReceivedAt:
          (data['lastProfitReceivedAt'] as dynamic)?.toDate() as DateTime?,
      idPhotoUrl: data['idPhotoUrl'] as String? ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String? ?? '',
      termsAcceptedAt:
          (data['termsAcceptedAt'] as dynamic)?.toDate() as DateTime?,
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      isBlocked: data['isBlocked'] as bool? ?? false,
      cancelledRidesCount: (data['cancelledRidesCount'] as num?)?.toInt() ?? 0,
      isRemoved: data['isRemoved'] as bool? ?? false,
      monthlyRideCount: (data['monthlyRideCount'] as num?)?.toInt() ?? 0,
      monthlyMonthKey: data['monthlyMonthKey'] as String? ?? '',
      isFakeDriver: data['isFakeDriver'] as bool? ?? false,
      autoAcceptRides: data['autoAcceptRides'] as bool? ?? false,
      hasActiveRide: data['hasActiveRide'] as bool? ?? false,
      geohash: data['geohash'] as String? ?? '',
      assignedDistrictId: data['assignedDistrictId'] as String? ?? '',
      assignedSubDistrictId: data['assignedSubDistrictId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
      'vehicleColor': vehicleColor,
      'licenseNumber': licenseNumber,
      'approvalStatus': approvalStatus.value,
      'isOnline': isOnline,
      'hasActiveRide': hasActiveRide,
      'rating': rating,
      'ratingCount': ratingCount,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (geohash.isNotEmpty) 'geohash': geohash,
      if (assignedDistrictId.isNotEmpty) 'assignedDistrictId': assignedDistrictId,
      if (assignedSubDistrictId.isNotEmpty)
        'assignedSubDistrictId': assignedSubDistrictId,
      if (locationUpdatedAt != null) 'locationUpdatedAt': locationUpdatedAt,
      'completedRidesCount': completedRidesCount,
      'totalFareCollectedIqd': totalFareCollectedIqd,
      'totalPlatformCommissionIqd': totalPlatformCommissionIqd,
      'outstandingPlatformCommissionIqd': outstandingPlatformCommissionIqd,
      'totalDriverEarningsIqd': totalDriverEarningsIqd,
      'pendingBonusIqd': pendingBonusIqd,
      'totalBonusGrantedIqd': totalBonusGrantedIqd,
      if (lastProfitReceivedAt != null)
        'lastProfitReceivedAt': lastProfitReceivedAt,
      'idPhotoUrl': idPhotoUrl,
      'profilePhotoUrl': profilePhotoUrl,
      if (termsAcceptedAt != null) 'termsAcceptedAt': termsAcceptedAt,
      if (createdAt != null) 'createdAt': createdAt,
      'isBlocked': isBlocked,
      'cancelledRidesCount': cancelledRidesCount,
      'isRemoved': isRemoved,
      'monthlyRideCount': monthlyRideCount,
      if (monthlyMonthKey.isNotEmpty) 'monthlyMonthKey': monthlyMonthKey,
      if (isFakeDriver) 'isFakeDriver': true,
      if (autoAcceptRides) 'autoAcceptRides': true,
    };
  }
}

class DriverBonus {
  const DriverBonus({
    required this.id,
    required this.driverId,
    required this.amountIqd,
    required this.reason,
    required this.createdBy,
    this.createdAt,
    this.isPaid = false,
    this.paidAt,
  });

  final String id;
  final String driverId;
  final int amountIqd;
  final String reason;
  final String createdBy;
  final DateTime? createdAt;
  final bool isPaid;
  final DateTime? paidAt;

  factory DriverBonus.fromMap(
    String id,
    String driverId,
    Map<String, dynamic> data,
  ) {
    return DriverBonus(
      id: id,
      driverId: driverId,
      amountIqd: (data['amountIqd'] as num?)?.toInt() ?? 0,
      reason: data['reason'] as String? ?? '',
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      isPaid: data['isPaid'] as bool? ?? false,
      paidAt: (data['paidAt'] as dynamic)?.toDate() as DateTime?,
    );
  }
}

class Ride {
  const Ride({
    required this.id,
    required this.customerId,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.status,
    this.driverId,
    this.createdAt,
    this.fareAmountIqd = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.cashCollectedByDriver = false,
    this.cashConfirmedByCustomer = false,
    this.commissionPercent,
    this.platformCommissionIqd = 0,
    this.driverEarningsIqd = 0,
    this.completedAt,
    this.driverRating,
    this.driverFeedback,
    this.ratedAt,
    this.districtId = '',
    this.subDistrictId = '',
    this.originalFareIqd = 0,
    this.promoDiscountIqd = 0,
    this.promoCode = '',
    this.offeredDriverIds = const [],
  });

  final String id;
  final String customerId;
  final String? driverId;
  final List<String> offeredDriverIds;
  final String pickupLabel;
  final String destinationLabel;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final RideStatus status;
  final DateTime? createdAt;
  final int fareAmountIqd;
  final PaymentMethod paymentMethod;
  final bool cashCollectedByDriver;
  final bool cashConfirmedByCustomer;
  final double? commissionPercent;
  final int platformCommissionIqd;
  final int driverEarningsIqd;
  final DateTime? completedAt;
  final int? driverRating;
  final String? driverFeedback;
  final DateTime? ratedAt;
  final String districtId;
  final String subDistrictId;
  final int originalFareIqd;
  final int promoDiscountIqd;
  final String promoCode;

  bool get isCashPaymentComplete => cashCollectedByDriver;

  factory Ride.fromMap(String id, Map<String, dynamic> data) {
    return Ride(
      id: id,
      customerId: data['customerId'] as String? ?? '',
      driverId: data['driverId'] as String?,
      pickupLabel: data['pickupLabel'] as String? ?? '',
      destinationLabel: data['destinationLabel'] as String? ?? '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0,
      pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0,
      destinationLat: (data['destinationLat'] as num?)?.toDouble() ?? 0,
      destinationLng: (data['destinationLng'] as num?)?.toDouble() ?? 0,
      status: RideStatusX.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
      fareAmountIqd: (data['fareAmountIqd'] as num?)?.toInt() ?? 0,
      paymentMethod: PaymentMethodX.fromString(data['paymentMethod'] as String?),
      cashCollectedByDriver: data['cashCollectedByDriver'] as bool? ?? false,
      cashConfirmedByCustomer:
          data['cashConfirmedByCustomer'] as bool? ?? false,
      commissionPercent: (data['commissionPercent'] as num?)?.toDouble(),
      platformCommissionIqd:
          (data['platformCommissionIqd'] as num?)?.toInt() ?? 0,
      driverEarningsIqd: (data['driverEarningsIqd'] as num?)?.toInt() ?? 0,
      completedAt: (data['completedAt'] as dynamic)?.toDate() as DateTime?,
      driverRating: (data['driverRating'] as num?)?.toInt(),
      driverFeedback: data['driverFeedback'] as String?,
      ratedAt: (data['ratedAt'] as dynamic)?.toDate() as DateTime?,
      districtId: data['districtId'] as String? ?? '',
      subDistrictId: data['subDistrictId'] as String? ?? '',
      originalFareIqd: (data['originalFareIqd'] as num?)?.toInt() ?? 0,
      promoDiscountIqd: (data['promoDiscountIqd'] as num?)?.toInt() ?? 0,
      promoCode: data['promoCode'] as String? ?? '',
      offeredDriverIds: (data['offeredDriverIds'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      if (driverId != null) 'driverId': driverId,
      if (offeredDriverIds.isNotEmpty) 'offeredDriverIds': offeredDriverIds,
      'pickupLabel': pickupLabel,
      'destinationLabel': destinationLabel,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'status': status.value,
      'createdAt': createdAt,
      'fareAmountIqd': fareAmountIqd,
      'paymentMethod': paymentMethod.value,
      'cashCollectedByDriver': cashCollectedByDriver,
      'cashConfirmedByCustomer': cashConfirmedByCustomer,
      if (commissionPercent != null) 'commissionPercent': commissionPercent,
      if (platformCommissionIqd > 0) 'platformCommissionIqd': platformCommissionIqd,
      if (driverEarningsIqd > 0) 'driverEarningsIqd': driverEarningsIqd,
      if (completedAt != null) 'completedAt': completedAt,
      if (driverRating != null) 'driverRating': driverRating,
      if (driverFeedback != null) 'driverFeedback': driverFeedback,
      if (ratedAt != null) 'ratedAt': ratedAt,
      if (districtId.isNotEmpty) 'districtId': districtId,
      if (subDistrictId.isNotEmpty) 'subDistrictId': subDistrictId,
      if (originalFareIqd > 0) 'originalFareIqd': originalFareIqd,
      if (promoDiscountIqd > 0) 'promoDiscountIqd': promoDiscountIqd,
      if (promoCode.isNotEmpty) 'promoCode': promoCode,
    };
  }
}

extension RidePromo on Ride {
  bool get usedPromo => promoCode.isNotEmpty && promoDiscountIqd > 0;

  int get fullFareBeforePromoIqd =>
      originalFareIqd > 0 ? originalFareIqd : fareAmountIqd + promoDiscountIqd;

  int get driverPromoCompensationIqd => promoDiscountIqd;
}

class PlaceResult {
  const PlaceResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;

  PlaceResult toPlaceResult() => PlaceResult(
        label: label,
        latitude: latitude,
        longitude: longitude,
      );

  factory SavedPlace.fromMap(String id, Map<String, dynamic> data) {
    return SavedPlace(
      id: id,
      label: data['label'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as dynamic)?.toDate() as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
    };
  }
}
