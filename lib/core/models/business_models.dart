import 'package:cloud_firestore/cloud_firestore.dart';

/// Database-driven business type (not hardcoded in apps).
class BusinessTypeConfig {
  const BusinessTypeConfig({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.icon = 'store',
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final String icon;
  final int sortOrder;
  final bool active;

  String nameForLocale(bool isAr) => isAr ? nameAr : nameEn;

  factory BusinessTypeConfig.fromMap(String id, Map<String, dynamic> data) {
    return BusinessTypeConfig(
      id: id,
      nameEn: data['nameEn'] as String? ?? id,
      nameAr: data['nameAr'] as String? ?? id,
      icon: data['icon'] as String? ?? 'store',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nameEn': nameEn,
        'nameAr': nameAr,
        'icon': icon,
        'sortOrder': sortOrder,
        'active': active,
      };
}

enum BusinessStatus {
  draft,
  pendingReview,
  approved,
  live,
  rejected,
  suspended,
  archived,
}

extension BusinessStatusX on BusinessStatus {
  String get value => name;

  bool get isCustomerVisible => this == BusinessStatus.live;

  static BusinessStatus fromString(String? raw) {
    return BusinessStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BusinessStatus.draft,
    );
  }
}

enum BusinessOrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  outForDelivery,
  delivered,
  cancelled,
  rejected,
}

extension BusinessOrderStatusX on BusinessOrderStatus {
  String get value => name;

  static BusinessOrderStatus fromString(String? raw) {
    return BusinessOrderStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => BusinessOrderStatus.pending,
    );
  }
}

class BusinessHoursDay {
  const BusinessHoursDay({
    this.open = '09:00',
    this.close = '22:00',
    this.closed = false,
  });

  final String open;
  final String close;
  final bool closed;

  Map<String, dynamic> toMap() => {
        'open': open,
        'close': close,
        'closed': closed,
      };

  factory BusinessHoursDay.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BusinessHoursDay();
    return BusinessHoursDay(
      open: data['open'] as String? ?? '09:00',
      close: data['close'] as String? ?? '22:00',
      closed: data['closed'] as bool? ?? false,
    );
  }
}

class BusinessHours {
  const BusinessHours({this.alwaysOpen = false, this.days = const {}});

  final bool alwaysOpen;
  final Map<String, BusinessHoursDay> days;

  Map<String, dynamic> toMap() => {
        'alwaysOpen': alwaysOpen,
        'days': {for (final e in days.entries) e.key: e.value.toMap()},
      };

  factory BusinessHours.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const BusinessHours();
    final rawDays = data['days'] as Map<String, dynamic>? ?? {};
    return BusinessHours(
      alwaysOpen: data['alwaysOpen'] as bool? ?? false,
      days: {
        for (final e in rawDays.entries)
          e.key: BusinessHoursDay.fromMap(
            e.value is Map ? Map<String, dynamic>.from(e.value as Map) : null,
          ),
      },
    );
  }
}

class BusinessPartner {
  const BusinessPartner({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.typeId,
    required this.status,
    this.descriptionEn = '',
    this.descriptionAr = '',
    this.logoUrl = '',
    this.coverUrl = '',
    this.phone = '',
    this.address = '',
    this.latitude = 0,
    this.longitude = 0,
    this.provinceId = '',
    this.districtId = '',
    this.subDistrictId = '',
    this.ownerUid = '',
    this.ownerEmail = '',
    this.commissionPercent = 15,
    this.rating = 0,
    this.ratingCount = 0,
    this.totalOrders = 0,
    this.totalRevenueIqd = 0,
    this.hours = const BusinessHours(),
    this.temporarilyClosed = false,
    this.createdAt,
    this.updatedAt,
    this.rejectionReason = '',
  });

  final String id;
  final String nameEn;
  final String nameAr;
  final String typeId;
  final BusinessStatus status;
  final String descriptionEn;
  final String descriptionAr;
  final String logoUrl;
  final String coverUrl;
  final String phone;
  final String address;
  final double latitude;
  final double longitude;
  final String provinceId;
  final String districtId;
  final String subDistrictId;
  final String ownerUid;
  final String ownerEmail;
  final double commissionPercent;
  final double rating;
  final int ratingCount;
  final int totalOrders;
  final int totalRevenueIqd;
  final BusinessHours hours;
  final bool temporarilyClosed;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String rejectionReason;

  String nameForLocale(bool isAr) => isAr ? nameAr : nameEn;

  bool get isLive => status == BusinessStatus.live;

  /// Visible and orderable in customer apps.
  bool get isCustomerOrderable => isLive && !temporarilyClosed;

  factory BusinessPartner.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return BusinessPartner(
      id: doc.id,
      nameEn: data['nameEn'] as String? ?? '',
      nameAr: data['nameAr'] as String? ?? '',
      typeId: data['typeId'] as String? ?? 'store',
      status: BusinessStatusX.fromString(data['status'] as String?),
      descriptionEn: data['descriptionEn'] as String? ?? '',
      descriptionAr: data['descriptionAr'] as String? ?? '',
      logoUrl: data['logoUrl'] as String? ?? '',
      coverUrl: data['coverUrl'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      provinceId: data['provinceId'] as String? ?? '',
      districtId: data['districtId'] as String? ?? '',
      subDistrictId: data['subDistrictId'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerEmail: data['ownerEmail'] as String? ?? '',
      commissionPercent: (data['commissionPercent'] as num?)?.toDouble() ?? 15,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
      totalRevenueIqd: (data['totalRevenueIqd'] as num?)?.toInt() ?? 0,
      hours: BusinessHours.fromMap(data['hours'] as Map<String, dynamic>?),
      temporarilyClosed: data['temporarilyClosed'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      rejectionReason: data['rejectionReason'] as String? ?? '',
    );
  }
}

class BusinessCategory {
  const BusinessCategory({
    required this.id,
    required this.businessId,
    required this.nameEn,
    required this.nameAr,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String businessId;
  final String nameEn;
  final String nameAr;
  final int sortOrder;
  final bool active;

  String nameForLocale(bool isAr) => isAr ? nameAr : nameEn;

  factory BusinessCategory.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String businessId,
  }) {
    final data = doc.data() ?? {};
    return BusinessCategory(
      id: doc.id,
      businessId: businessId,
      nameEn: data['nameEn'] as String? ?? '',
      nameAr: data['nameAr'] as String? ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'nameEn': nameEn,
        'nameAr': nameAr,
        'sortOrder': sortOrder,
        'active': active,
      };
}

class BusinessProduct {
  const BusinessProduct({
    required this.id,
    required this.businessId,
    required this.categoryId,
    required this.nameEn,
    required this.nameAr,
    required this.priceIqd,
    this.descriptionEn = '',
    this.descriptionAr = '',
    this.imageUrl = '',
    this.discountPercent = 0,
    this.available = true,
    this.prepMinutes = 15,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String businessId;
  final String categoryId;
  final String nameEn;
  final String nameAr;
  final String descriptionEn;
  final String descriptionAr;
  final String imageUrl;
  final int priceIqd;
  final double discountPercent;
  final bool available;
  final int prepMinutes;
  final int sortOrder;
  final DateTime? createdAt;

  String nameForLocale(bool isAr) => isAr ? nameAr : nameEn;

  int get effectivePriceIqd {
    if (discountPercent <= 0) return priceIqd;
    return (priceIqd * (100 - discountPercent) / 100).round();
  }

  factory BusinessProduct.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String businessId,
  }) {
    final data = doc.data() ?? {};
    return BusinessProduct(
      id: doc.id,
      businessId: businessId,
      categoryId: data['categoryId'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? '',
      nameAr: data['nameAr'] as String? ?? '',
      descriptionEn: data['descriptionEn'] as String? ?? '',
      descriptionAr: data['descriptionAr'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      priceIqd: (data['priceIqd'] as num?)?.toInt() ?? 0,
      discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
      available: data['available'] as bool? ?? true,
      prepMinutes: (data['prepMinutes'] as num?)?.toInt() ?? 15,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'descriptionEn': descriptionEn,
        'descriptionAr': descriptionAr,
        'imageUrl': imageUrl,
        'priceIqd': priceIqd,
        'discountPercent': discountPercent,
        'available': available,
        'prepMinutes': prepMinutes,
        'sortOrder': sortOrder,
      };
}

class BusinessOrderItem {
  const BusinessOrderItem({
    required this.productId,
    required this.nameEn,
    required this.nameAr,
    required this.unitPriceIqd,
    required this.quantity,
  });

  final String productId;
  final String nameEn;
  final String nameAr;
  final int unitPriceIqd;
  final int quantity;

  int get lineTotalIqd => unitPriceIqd * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'nameEn': nameEn,
        'nameAr': nameAr,
        'unitPriceIqd': unitPriceIqd,
        'quantity': quantity,
      };

  factory BusinessOrderItem.fromMap(Map<String, dynamic> data) {
    return BusinessOrderItem(
      productId: data['productId'] as String? ?? '',
      nameEn: data['nameEn'] as String? ?? '',
      nameAr: data['nameAr'] as String? ?? '',
      unitPriceIqd: (data['unitPriceIqd'] as num?)?.toInt() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class BusinessOrder {
  const BusinessOrder({
    required this.id,
    required this.businessId,
    required this.customerId,
    required this.status,
    required this.items,
    required this.subtotalIqd,
    required this.deliveryFeeIqd,
    required this.totalIqd,
    this.businessName = '',
    this.customerName = '',
    this.customerPhone = '',
    this.driverId = '',
    this.districtId = '',
    this.subDistrictId = '',
    this.pickupLat = 0,
    this.pickupLng = 0,
    this.dropoffLat = 0,
    this.dropoffLng = 0,
    this.dropoffLabel = '',
    this.notes = '',
    this.platformCommissionIqd = 0,
    this.businessEarningsIqd = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String driverId;
  final BusinessOrderStatus status;
  final List<BusinessOrderItem> items;
  final int subtotalIqd;
  final int deliveryFeeIqd;
  final int totalIqd;
  final int platformCommissionIqd;
  final int businessEarningsIqd;
  final String districtId;
  final String subDistrictId;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String dropoffLabel;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BusinessOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return BusinessOrder(
      id: doc.id,
      businessId: data['businessId'] as String? ?? '',
      businessName: data['businessName'] as String? ?? '',
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      driverId: data['driverId'] as String? ?? '',
      status: BusinessOrderStatusX.fromString(data['status'] as String?),
      items: rawItems
          .whereType<Map>()
          .map((e) => BusinessOrderItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      subtotalIqd: (data['subtotalIqd'] as num?)?.toInt() ?? 0,
      deliveryFeeIqd: (data['deliveryFeeIqd'] as num?)?.toInt() ?? 0,
      totalIqd: (data['totalIqd'] as num?)?.toInt() ?? 0,
      platformCommissionIqd: (data['platformCommissionIqd'] as num?)?.toInt() ?? 0,
      businessEarningsIqd: (data['businessEarningsIqd'] as num?)?.toInt() ?? 0,
      districtId: data['districtId'] as String? ?? '',
      subDistrictId: data['subDistrictId'] as String? ?? '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? 0,
      pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? 0,
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble() ?? 0,
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble() ?? 0,
      dropoffLabel: data['dropoffLabel'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
