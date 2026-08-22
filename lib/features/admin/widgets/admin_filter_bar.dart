import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/admin/widgets/admin_chrome.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Reusable advanced filter bar for Admin Dashboard pages.
class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.fields = const [
      AdminFilterField.province,
      AdminFilterField.district,
      AdminFilterField.subDistrict,
      AdminFilterField.dateRange,
      AdminFilterField.search,
    ],
    this.hintText,
    this.margin = const EdgeInsets.fromLTRB(12, 12, 12, 0),
  });

  final AdminFilterCriteria value;
  final ValueChanged<AdminFilterCriteria> onChanged;
  final List<AdminFilterField> fields;
  final String? hintText;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return ListenableBuilder(
      listenable: ServiceAreaCatalog.instance,
      builder: (context, _) {
        final catalog = ServiceAreaCatalog.instance;
        final provinces = catalog.provincesForAdminFilters;
        final districts = catalog.districtsForProvince(value.provinceId);
        final subs = catalog.subsForDistrict(value.districtId);

        return Container(
          margin: margin,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AdminChrome.cardBorder),
            boxShadow: AdminChrome.cardShadow,
          ),
          child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppBrandAssets.brandTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_alt_outlined,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        isAr ? 'تصفية' : 'Filter',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (fields.contains(AdminFilterField.province))
                  _Dropdown<String?>(
                    label: isAr ? 'المحافظة' : 'Governorate',
                    value: _safeValue(value.provinceId, provinces.map((p) => p.id)),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(isAr ? 'الكل' : 'All'),
                      ),
                      for (final p in provinces)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(isAr ? p.nameAr : p.nameEn),
                        ),
                    ],
                    onChanged: (v) => onChanged(
                      value.copyWith(
                        provinceId: v,
                        clearProvince: v == null,
                        clearDistrict: true,
                        clearSubDistrict: true,
                      ),
                    ),
                  ),
                if (fields.contains(AdminFilterField.district))
                  _Dropdown<String?>(
                    label: isAr ? 'القضاء' : 'District',
                    value: _safeValue(value.districtId, districts.map((d) => d.id)),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(isAr ? 'الكل' : 'All'),
                      ),
                      for (final d in districts)
                        DropdownMenuItem(
                          value: d.id,
                          child: Text(isAr ? d.nameAr : d.nameEn),
                        ),
                    ],
                    onChanged: (v) => onChanged(
                      value.copyWith(
                        districtId: v,
                        clearDistrict: v == null,
                        clearSubDistrict: true,
                        provinceId: v == null
                            ? value.provinceId
                            : (catalog.provinceIdForDistrict(v) ??
                                value.provinceId),
                      ),
                    ),
                  ),
                if (fields.contains(AdminFilterField.subDistrict))
                  _Dropdown<String?>(
                    label: isAr ? 'الناحية' : 'Sub-district',
                    value: _safeValue(value.subDistrictId, subs.map((s) => s.id)),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(isAr ? 'الكل' : 'All'),
                      ),
                      for (final s in subs)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(isAr ? s.nameAr : s.nameEn),
                        ),
                    ],
                    onChanged: (v) => onChanged(
                      value.copyWith(
                        subDistrictId: v,
                        clearSubDistrict: v == null,
                      ),
                    ),
                  ),
                ..._buildOtherFields(context, isAr),
              ],
          ),
        );
      },
    );
  }

  String? _safeValue(String? selected, Iterable<String> allowed) {
    if (selected == null || selected.isEmpty) return null;
    return allowed.contains(selected) ? selected : null;
  }

  List<Widget> _buildOtherFields(BuildContext context, bool isAr) {
    return [
            if (fields.contains(AdminFilterField.businessType))
              StreamBuilder<List<BusinessTypeConfig>>(
                stream:
                    context.read<AppState>().businessService.watchBusinessTypes(),
                builder: (context, snap) {
                  final types = snap.data ?? const <BusinessTypeConfig>[];
                  return _Dropdown<String?>(
                    label: isAr ? 'نوع النشاط' : 'Business type',
                    value: value.businessTypeId,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(isAr ? 'الكل' : 'All'),
                      ),
                      for (final t in types)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(isAr ? t.nameAr : t.nameEn),
                        ),
                    ],
                    onChanged: (v) => onChanged(
                      value.copyWith(
                        businessTypeId: v,
                        clearBusinessType: v == null,
                      ),
                    ),
                  );
                },
              ),
            if (fields.contains(AdminFilterField.driverStatus))
              _Dropdown<String?>(
                label: isAr ? 'حالة السائق' : 'Driver status',
                value: value.driverStatus,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(isAr ? 'الكل' : 'All'),
                  ),
                  DropdownMenuItem(
                    value: 'online',
                    child: Text(isAr ? 'متصل' : 'Online'),
                  ),
                  DropdownMenuItem(
                    value: 'offline',
                    child: Text(isAr ? 'غير متصل' : 'Offline'),
                  ),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text(isAr ? 'مقبول' : 'Approved'),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text(isAr ? 'قيد المراجعة' : 'Pending'),
                  ),
                  DropdownMenuItem(
                    value: 'blocked',
                    child: Text(isAr ? 'محظور' : 'Blocked'),
                  ),
                  DropdownMenuItem(
                    value: 'busy',
                    child: Text(isAr ? 'مشغول' : 'Busy'),
                  ),
                ],
                onChanged: (v) => onChanged(
                  value.copyWith(
                    driverStatus: v,
                    clearDriverStatus: v == null,
                  ),
                ),
              ),
            if (fields.contains(AdminFilterField.customerStatus))
              _Dropdown<String?>(
                label: isAr ? 'حالة الزبون' : 'Customer status',
                value: value.customerStatus,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(isAr ? 'الكل' : 'All'),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text(isAr ? 'نشط' : 'Active'),
                  ),
                  DropdownMenuItem(
                    value: 'blocked',
                    child: Text(isAr ? 'محظور' : 'Blocked'),
                  ),
                ],
                onChanged: (v) => onChanged(
                  value.copyWith(
                    customerStatus: v,
                    clearCustomerStatus: v == null,
                  ),
                ),
              ),
            if (fields.contains(AdminFilterField.rideStatus))
              _Dropdown<String?>(
                label: isAr ? 'حالة الرحلة' : 'Ride status',
                value: value.rideStatus,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(isAr ? 'الكل' : 'All'),
                  ),
                  for (final s in const [
                    'searching',
                    'matched',
                    'accepted',
                    'inProgress',
                    'awaitingCashPayment',
                    'completed',
                    'cancelled',
                  ])
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => onChanged(
                  value.copyWith(rideStatus: v, clearRideStatus: v == null),
                ),
              ),
            if (fields.contains(AdminFilterField.orderStatus))
              _Dropdown<String?>(
                label: isAr ? 'حالة الطلب' : 'Order status',
                value: value.orderStatus,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(isAr ? 'الكل' : 'All'),
                  ),
                  for (final s in const [
                    'pending',
                    'accepted',
                    'preparing',
                    'ready',
                    'outForDelivery',
                    'delivered',
                    'cancelled',
                  ])
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => onChanged(
                  value.copyWith(orderStatus: v, clearOrderStatus: v == null),
                ),
              ),
            if (fields.contains(AdminFilterField.dateRange)) ...[
              _DateChip(
                label: isAr ? 'من' : 'From',
                value: value.dateFrom,
                onPick: (d) => onChanged(
                  value.copyWith(dateFrom: d, clearDateFrom: d == null),
                ),
              ),
              _DateChip(
                label: isAr ? 'إلى' : 'To',
                value: value.dateTo,
                onPick: (d) => onChanged(
                  value.copyWith(dateTo: d, clearDateTo: d == null),
                ),
              ),
            ],
            if (fields.contains(AdminFilterField.search))
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: hintText ?? (isAr ? 'بحث' : 'Search'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (q) => onChanged(value.copyWith(query: q)),
                ),
              ),
            TextButton.icon(
              onPressed: () => onChanged(AdminFilterCriteria.empty),
              icon: const Icon(Icons.clear_all),
              label: Text(isAr ? 'مسح' : 'Clear'),
            ),
    ];
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return ActionChip(
      avatar: const Icon(Icons.calendar_today, size: 16),
      label: Text(
        value == null ? label : '$label: ${fmt.format(value!)}',
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        onPick(picked);
      },
    );
  }
}
