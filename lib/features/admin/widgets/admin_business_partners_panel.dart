import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminBusinessPartnersPanel extends StatefulWidget {
  const AdminBusinessPartnersPanel({super.key});

  @override
  State<AdminBusinessPartnersPanel> createState() =>
      _AdminBusinessPartnersPanelState();
}

class _AdminBusinessPartnersPanelState extends State<AdminBusinessPartnersPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _selectedId;
  var _seeding = false;
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final biz = context.watch<AppState>().businessService;
    const fare = FareService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr ? 'شركاء الأعمال' : 'Business Partners',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _seeding
                        ? null
                        : () async {
                            setState(() => _seeding = true);
                            try {
                              await biz.seedBusinessTypes();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isAr
                                        ? 'تم نشر أنواع الأعمال'
                                        : 'Business types seeded',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            } finally {
                              if (mounted) setState(() => _seeding = false);
                            }
                          },
                    icon: const Icon(Icons.category_outlined),
                    label: Text(isAr ? 'أنواع الأعمال' : 'Seed types'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _createBusiness(context, isAr),
                    icon: const Icon(Icons.add_business),
                    label: Text(isAr ? 'شريك جديد' : 'New partner'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            isAr
                ? 'المدير ينشئ حساب الشريك، ثم يضيف الشريك الأصناف والأسعار والصور من بوابة الأعمال. تظهر للزبائن بعد التفعيل (Live).'
                : 'Admin creates the partner login. The partner then adds items, prices, and photos in the Business Portal. Customers see it only after Go live.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: isAr ? 'الشركاء' : 'Partners'),
            Tab(text: isAr ? 'الطلبات' : 'Orders'),
            Tab(text: isAr ? 'الأنواع' : 'Types'),
          ],
        ),
        if (_tabs.index == 0)
          AdminFilterBar(
            value: _filters,
            onChanged: (v) => setState(() => _filters = v),
            fields: const [
              AdminFilterField.businessType,
              AdminFilterField.province,
              AdminFilterField.district,
              AdminFilterField.subDistrict,
              AdminFilterField.search,
            ],
          )
        else if (_tabs.index == 1)
          AdminFilterBar(
            value: _filters,
            onChanged: (v) => setState(() => _filters = v),
            fields: const [
              AdminFilterField.businessType,
              AdminFilterField.province,
              AdminFilterField.district,
              AdminFilterField.subDistrict,
              AdminFilterField.orderStatus,
              AdminFilterField.dateRange,
              AdminFilterField.search,
            ],
          ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              StreamBuilder<List<BusinessPartner>>(
                stream: biz.watchBusinesses(limit: 150),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('${snap.error}'));
                  }
                  final items = (snap.data ?? const []).where((b) {
                    if (_filters.businessTypeId != null &&
                        b.typeId != _filters.businessTypeId) {
                      return false;
                    }
                    if (!_filters.matchesGeo(
                      provinceId: b.provinceId,
                      districtId: b.districtId,
                      subDistrictId: b.subDistrictId,
                    )) {
                      return false;
                    }
                    final q = _filters.query.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      final haystack =
                          '${b.nameEn} ${b.nameAr} ${b.ownerEmail} ${b.phone} ${b.typeId}'
                              .toLowerCase();
                      if (!haystack.contains(q)) return false;
                    }
                    return true;
                  }).toList();
                  if (items.isEmpty) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isAr
                                    ? 'لا شركاء بعد'
                                    : 'No partners yet',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isAr
                                    ? '1) Seed types  2) New partner (email + password)  3) Partner logs into Business Portal and adds products'
                                    : '1) Seed types  2) New partner (email + password)  3) Partner logs into Business Portal and adds products',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => _createBusiness(context, isAr),
                                icon: const Icon(Icons.add_business),
                                label: Text(
                                  isAr ? 'إنشاء شريك جديد' : 'Create new partner',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final b = items[i];
                      return Card(
                        color: _selectedId == b.id
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.35)
                            : null,
                        child: ListTile(
                          onTap: () => setState(() => _selectedId = b.id),
                          leading: CircleAvatar(
                            backgroundImage: b.logoUrl.isNotEmpty
                                ? NetworkImage(b.logoUrl)
                                : null,
                            child: b.logoUrl.isEmpty
                                ? const Icon(Icons.storefront)
                                : null,
                          ),
                          title: Text(b.nameForLocale(isAr)),
                          subtitle: Text(
                            [
                              b.typeId,
                              _statusLabel(b.status, isAr),
                              if (b.ownerEmail.isNotEmpty) b.ownerEmail,
                              '${isAr ? 'طلبات' : 'Orders'}: ${b.totalOrders}',
                              fare.formatIqd(b.totalRevenueIqd),
                            ].join(' • '),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) => _onAction(
                              context,
                              business: b,
                              action: v,
                              isAr: isAr,
                            ),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'live',
                                child: Text(isAr ? 'تفعيل مباشر' : 'Go live'),
                              ),
                              PopupMenuItem(
                                value: 'suspend',
                                child: Text(isAr ? 'تعليق' : 'Suspend'),
                              ),
                              PopupMenuItem(
                                value: 'approve',
                                child: Text(isAr ? 'موافقة' : 'Approve'),
                              ),
                              PopupMenuItem(
                                value: 'reject',
                                child: Text(isAr ? 'رفض' : 'Reject'),
                              ),
                              PopupMenuItem(
                                value: 'archive',
                                child: Text(isAr ? 'أرشفة' : 'Archive'),
                              ),
                              PopupMenuItem(
                                value: 'commission',
                                child: Text(isAr ? 'العمولة' : 'Commission'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(isAr ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              StreamBuilder<List<BusinessOrder>>(
                stream: biz.watchAllOrders(),
                builder: (context, snap) {
                  final items = (snap.data ?? const []).where((o) {
                    if (_filters.orderStatus != null &&
                        o.status.value != _filters.orderStatus) {
                      return false;
                    }
                    if (!_filters.matchesGeo(
                      districtId: o.districtId,
                      subDistrictId: o.subDistrictId,
                    )) {
                      return false;
                    }
                    if (!_filters.matchesDate(o.createdAt)) return false;
                    final q = _filters.query.trim().toLowerCase();
                    if (q.isNotEmpty) {
                      final haystack =
                          '${o.businessName} ${o.customerName} ${o.customerPhone} ${o.id}'
                              .toLowerCase();
                      if (!haystack.contains(q)) return false;
                    }
                    return true;
                  }).toList();
                  if (items.isEmpty) {
                    return Center(
                      child: Text(isAr ? 'لا طلبات بعد' : 'No orders yet'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final o = items[i];
                      return ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(o.businessName.isEmpty
                            ? o.businessId
                            : o.businessName),
                        subtitle: Text(
                          [
                            o.status.value,
                            o.customerName,
                            fare.formatIqd(o.totalIqd),
                          ].join(' • '),
                        ),
                      );
                    },
                  );
                },
              ),
              StreamBuilder<List<BusinessTypeConfig>>(
                stream: biz.watchBusinessTypes(),
                builder: (context, snap) {
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        isAr
                            ? 'اضغط "أنواع الأعمال" لنشر القائمة الافتراضية'
                            : 'Tap “Seed types” to publish default types',
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final t = items[i];
                      return ListTile(
                        leading: const Icon(Icons.label_outline),
                        title: Text(t.nameForLocale(isAr)),
                        subtitle: Text('${t.id} • order ${t.sortOrder}'),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onAction(
    BuildContext context, {
    required BusinessPartner business,
    required String action,
    required bool isAr,
  }) async {
    final biz = context.read<AppState>().businessService;
    try {
      switch (action) {
        case 'live':
          await biz.setBusinessStatus(
            businessId: business.id,
            status: BusinessStatus.live,
          );
          break;
        case 'suspend':
          await biz.setBusinessStatus(
            businessId: business.id,
            status: BusinessStatus.suspended,
          );
          break;
        case 'approve':
          await biz.setBusinessStatus(
            businessId: business.id,
            status: BusinessStatus.approved,
          );
          break;
        case 'reject':
          final reason = await _askText(
            context,
            isAr ? 'سبب الرفض' : 'Rejection reason',
            isAr,
          );
          if (reason == null) return;
          await biz.setBusinessStatus(
            businessId: business.id,
            status: BusinessStatus.rejected,
            rejectionReason: reason,
          );
          break;
        case 'archive':
          await biz.setBusinessStatus(
            businessId: business.id,
            status: BusinessStatus.archived,
          );
          break;
        case 'commission':
          final raw = await _askText(
            context,
            isAr ? 'نسبة العمولة %' : 'Commission %',
            isAr,
            initial: business.commissionPercent.toString(),
          );
          if (raw == null) return;
          await biz.saveBusinessProfile(
            businessId: business.id,
            data: {'commissionPercent': double.tryParse(raw) ?? 15},
          );
          break;
        case 'delete':
          await biz.deleteBusiness(business.id);
          break;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _askText(
    BuildContext context,
    String title,
    bool isAr, {
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBusiness(BuildContext context, bool isAr) async {
    final nameEn = TextEditingController();
    final nameAr = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController(text: 'HelloBiz1!');
    final ownerName = TextEditingController();
    final phone = TextEditingController();
    var typeId = 'restaurant';
    final types = await context
        .read<AppState>()
        .businessService
        .watchBusinessTypes()
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () => const []);

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isAr ? 'إنشاء شريك أعمال' : 'Create business partner'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameEn,
                    decoration: const InputDecoration(labelText: 'Name EN'),
                  ),
                  TextField(
                    controller: nameAr,
                    decoration: const InputDecoration(labelText: 'Name AR'),
                  ),
                  DropdownButtonFormField<String>(
                    value: typeId,
                    decoration: InputDecoration(
                      labelText: isAr ? 'النوع' : 'Type',
                    ),
                    items: [
                      for (final t in (types.isEmpty
                          ? [
                              const BusinessTypeConfig(
                                id: 'restaurant',
                                nameEn: 'Restaurant',
                                nameAr: 'مطعم',
                              ),
                            ]
                          : types))
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(t.nameForLocale(isAr)),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => typeId = v!),
                  ),
                  TextField(
                    controller: ownerName,
                    decoration: InputDecoration(
                      labelText: isAr ? 'اسم المالك' : 'Owner name',
                    ),
                  ),
                  TextField(
                    controller: email,
                    decoration: InputDecoration(
                      labelText: isAr ? 'بريديل الدخول' : 'Owner login email',
                    ),
                  ),
                  TextField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: isAr ? 'كلمة المرور' : 'Temp password',
                    ),
                  ),
                  TextField(
                    controller: phone,
                    decoration: InputDecoration(
                      labelText: isAr ? 'الهاتف' : 'Phone',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isAr ? 'إنشاء' : 'Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final result =
          await context.read<AppState>().businessService.createBusinessPartner(
                nameEn: nameEn.text.trim(),
                nameAr: nameAr.text.trim(),
                typeId: typeId,
                ownerEmail: email.text.trim(),
                ownerPassword: password.text,
                ownerName: ownerName.text.trim(),
                phone: phone.text.trim(),
              );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تم الإنشاء — بوابة الأعمال: ${result['businessId']}'
                : 'Created — Business ID: ${result['businessId']}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

String _statusLabel(BusinessStatus status, bool isAr) {
  return switch (status) {
    BusinessStatus.draft => isAr ? 'مسودة' : 'draft',
    BusinessStatus.pendingReview => isAr ? 'بانتظار المراجعة' : 'pending review',
    BusinessStatus.approved => isAr ? 'موافق عليه' : 'approved',
    BusinessStatus.live => isAr ? 'مباشر' : 'live',
    BusinessStatus.rejected => isAr ? 'مرفوض' : 'rejected',
    BusinessStatus.suspended => isAr ? 'معلق' : 'suspended',
    BusinessStatus.archived => isAr ? 'مؤرشف' : 'archived',
  };
}
