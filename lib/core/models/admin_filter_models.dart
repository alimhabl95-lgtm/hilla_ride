/// Shared advanced filter criteria for Admin Dashboard pages.
class AdminFilterCriteria {
  const AdminFilterCriteria({
    this.provinceId,
    this.districtId,
    this.subDistrictId,
    this.businessTypeId,
    this.driverStatus,
    this.customerStatus,
    this.rideStatus,
    this.orderStatus,
    this.dateFrom,
    this.dateTo,
    this.query = '',
  });

  final String? provinceId;
  final String? districtId;
  final String? subDistrictId;
  final String? businessTypeId;
  final String? driverStatus;
  final String? customerStatus;
  final String? rideStatus;
  final String? orderStatus;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String query;

  static const empty = AdminFilterCriteria();

  bool get hasGeo =>
      (provinceId != null && provinceId!.isNotEmpty) ||
      (districtId != null && districtId!.isNotEmpty) ||
      (subDistrictId != null && subDistrictId!.isNotEmpty);

  bool get hasDateRange => dateFrom != null || dateTo != null;

  AdminFilterCriteria copyWith({
    String? provinceId,
    String? districtId,
    String? subDistrictId,
    String? businessTypeId,
    String? driverStatus,
    String? customerStatus,
    String? rideStatus,
    String? orderStatus,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? query,
    bool clearProvince = false,
    bool clearDistrict = false,
    bool clearSubDistrict = false,
    bool clearBusinessType = false,
    bool clearDriverStatus = false,
    bool clearCustomerStatus = false,
    bool clearRideStatus = false,
    bool clearOrderStatus = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return AdminFilterCriteria(
      provinceId: clearProvince ? null : (provinceId ?? this.provinceId),
      districtId: clearDistrict ? null : (districtId ?? this.districtId),
      subDistrictId:
          clearSubDistrict ? null : (subDistrictId ?? this.subDistrictId),
      businessTypeId:
          clearBusinessType ? null : (businessTypeId ?? this.businessTypeId),
      driverStatus:
          clearDriverStatus ? null : (driverStatus ?? this.driverStatus),
      customerStatus:
          clearCustomerStatus ? null : (customerStatus ?? this.customerStatus),
      rideStatus: clearRideStatus ? null : (rideStatus ?? this.rideStatus),
      orderStatus: clearOrderStatus ? null : (orderStatus ?? this.orderStatus),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      query: query ?? this.query,
    );
  }

  bool matchesDate(DateTime? value) {
    if (value == null) return !hasDateRange;
    if (dateFrom != null && value.isBefore(dateFrom!)) return false;
    if (dateTo != null) {
      final end = DateTime(dateTo!.year, dateTo!.month, dateTo!.day, 23, 59, 59);
      if (value.isAfter(end)) return false;
    }
    return true;
  }

  bool matchesGeo({
    String? provinceId,
    String? districtId,
    String? subDistrictId,
  }) {
    if (this.provinceId != null &&
        this.provinceId!.isNotEmpty &&
        (provinceId ?? '') != this.provinceId) {
      return false;
    }
    if (this.districtId != null &&
        this.districtId!.isNotEmpty &&
        (districtId ?? '') != this.districtId) {
      return false;
    }
    if (this.subDistrictId != null &&
        this.subDistrictId!.isNotEmpty &&
        (subDistrictId ?? '') != this.subDistrictId) {
      return false;
    }
    return true;
  }
}

enum AdminFilterField {
  province,
  district,
  subDistrict,
  businessType,
  driverStatus,
  customerStatus,
  rideStatus,
  orderStatus,
  dateRange,
  search,
}
