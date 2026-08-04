import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/business/screens/business_login_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Secure web portal for approved business owners.
class BusinessPortalShell extends StatelessWidget {
  const BusinessPortalShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AppState>().authService;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data == null) {
          return const BusinessLoginScreen();
        }
        return StreamBuilder<AppUser?>(
          stream: auth.watchCurrentProfile(),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            if (profile == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (profile.role != UserRole.businessOwner ||
                profile.businessId.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.localeName.startsWith('ar')
                      ? 'هذا الحساب ليس مالك عمل'
                      : 'This account is not a business owner',
                ),
              );
            }
            return _BusinessPortalHome(
              owner: profile,
              businessId: profile.businessId,
            );
          },
        );
      },
    );
  }
}

class _BusinessPortalHome extends StatefulWidget {
  const _BusinessPortalHome({
    required this.owner,
    required this.businessId,
  });

  final AppUser owner;
  final String businessId;

  @override
  State<_BusinessPortalHome> createState() => _BusinessPortalHomeState();
}

class _BusinessPortalHomeState extends State<_BusinessPortalHome> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAr =
        AppLocalizations.of(context)!.localeName.startsWith('ar');
    // Wide = web portal rail; narrow = same tabs for future mobile Business app.
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [
      _DashboardTab(businessId: widget.businessId, isAr: isAr),
      _ProfileTab(businessId: widget.businessId, isAr: isAr),
      _CategoriesTab(businessId: widget.businessId, isAr: isAr),
      _ProductsTab(businessId: widget.businessId, isAr: isAr),
      _OrdersTab(businessId: widget.businessId, isAr: isAr),
    ];

    if (!wide) {
      return Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: isAr ? 'لوحة' : 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.store_outlined),
              selectedIcon: const Icon(Icons.store),
              label: isAr ? 'الملف' : 'Profile',
            ),
            NavigationDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: const Icon(Icons.category),
              label: isAr ? 'تصنيف' : 'Categories',
            ),
            NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: isAr ? 'منتجات' : 'Products',
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: isAr ? 'طلبات' : 'Orders',
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelType: NavigationRailLabelType.all,
          destinations: [
            NavigationRailDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: Text(isAr ? 'لوحة التحكم' : 'Dashboard'),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.store_outlined),
              selectedIcon: const Icon(Icons.store),
              label: Text(isAr ? 'الملف' : 'Profile'),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.category_outlined),
              selectedIcon: const Icon(Icons.category),
              label: Text(isAr ? 'التصنيفات' : 'Categories'),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: Text(isAr ? 'المنتجات' : 'Products'),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: Text(isAr ? 'الطلبات' : 'Orders'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: IndexedStack(index: _index, children: pages)),
      ],
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.businessId, required this.isAr});
  final String businessId;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<AppState>().businessService;
    const fare = FareService();
    return StreamBuilder<BusinessPartner?>(
      stream: biz.watchBusiness(businessId),
      builder: (context, bizSnap) {
        final business = bizSnap.data;
        return StreamBuilder<List<BusinessOrder>>(
          stream: biz.watchOrdersForBusiness(businessId),
          builder: (context, orderSnap) {
            final orders = orderSnap.data ?? const [];
            final today = DateTime.now();
            final todayOrders = orders.where((o) {
              final c = o.createdAt;
              return c != null &&
                  c.year == today.year &&
                  c.month == today.month &&
                  c.day == today.day;
            }).toList();
            int count(BusinessOrderStatus s) =>
                orders.where((o) => o.status == s).length;
            final dailyRevenue = todayOrders.fold<int>(
              0,
              (sum, o) => sum + o.businessEarningsIqd,
            );

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  business?.nameForLocale(isAr) ??
                      (isAr ? 'لوحة العمل' : 'Business dashboard'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${isAr ? 'الحالة' : 'Status'}: ${business?.status.value ?? '-'}',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      label: isAr ? 'طلبات اليوم' : 'Today’s orders',
                      value: '${todayOrders.length}',
                    ),
                    _StatCard(
                      label: isAr ? 'معلقة' : 'Pending',
                      value: '${count(BusinessOrderStatus.pending)}',
                    ),
                    _StatCard(
                      label: isAr ? 'قيد التحضير' : 'Preparing',
                      value: '${count(BusinessOrderStatus.preparing)}',
                    ),
                    _StatCard(
                      label: isAr ? 'تم التوصيل' : 'Delivered',
                      value: '${count(BusinessOrderStatus.delivered)}',
                    ),
                    _StatCard(
                      label: isAr ? 'إيراد اليوم' : 'Daily revenue',
                      value: fare.formatIqd(dailyRevenue),
                    ),
                    _StatCard(
                      label: isAr ? 'إيراد كلي' : 'Total revenue',
                      value: fare.formatIqd(business?.totalRevenueIqd ?? 0),
                    ),
                    _StatCard(
                      label: isAr ? 'التقييم' : 'Rating',
                      value:
                          '${(business?.rating ?? 0).toStringAsFixed(1)} (${business?.ratingCount ?? 0})',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (business != null &&
                    business.status != BusinessStatus.live &&
                    business.status != BusinessStatus.pendingReview)
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await biz.submitBusinessForReview(businessId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAr
                                  ? 'تم الإرسال للمراجعة'
                                  : 'Submitted for review',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: Text(
                      isAr ? 'إرسال للمراجعة' : 'Submit for review',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.businessId, required this.isAr});
  final String businessId;
  final bool isAr;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _nameEn = TextEditingController();
  final _nameAr = TextEditingController();
  final _descEn = TextEditingController();
  final _descAr = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  var _loaded = false;

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _descEn.dispose();
    _descAr.dispose();
    _phone.dispose();
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _hydrate(BusinessPartner b) {
    if (_loaded) return;
    _nameEn.text = b.nameEn;
    _nameAr.text = b.nameAr;
    _descEn.text = b.descriptionEn;
    _descAr.text = b.descriptionAr;
    _phone.text = b.phone;
    _address.text = b.address;
    _lat.text = b.latitude == 0 ? '' : '${b.latitude}';
    _lng.text = b.longitude == 0 ? '' : '${b.longitude}';
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<AppState>().businessService;
    return StreamBuilder<BusinessPartner?>(
      stream: biz.watchBusiness(widget.businessId),
      builder: (context, snap) {
        final b = snap.data;
        if (b != null) _hydrate(b);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              widget.isAr ? 'ملف العمل' : 'Business profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (b != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  widget.isAr ? 'إغلاق مؤقت' : 'Temporarily closed',
                ),
                subtitle: Text(
                  widget.isAr
                      ? 'يخفي المتجر من الزبائن دون تغيير حالة الموافقة'
                      : 'Hides the store from customers without changing approval status',
                ),
                value: b.temporarilyClosed,
                onChanged: (value) async {
                  try {
                    await biz.saveBusinessProfile(
                      businessId: widget.businessId,
                      data: {'temporarilyClosed': value},
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
              ),
              const Divider(),
            ],
            TextField(
              controller: _nameEn,
              decoration: const InputDecoration(labelText: 'Name EN'),
            ),
            TextField(
              controller: _nameAr,
              decoration: const InputDecoration(labelText: 'Name AR'),
            ),
            TextField(
              controller: _descEn,
              decoration: const InputDecoration(labelText: 'Description EN'),
              maxLines: 2,
            ),
            TextField(
              controller: _descAr,
              decoration: const InputDecoration(labelText: 'Description AR'),
              maxLines: 2,
            ),
            TextField(
              controller: _phone,
              decoration: InputDecoration(
                labelText: widget.isAr ? 'الهاتف' : 'Phone',
              ),
            ),
            TextField(
              controller: _address,
              decoration: InputDecoration(
                labelText: widget.isAr ? 'العنوان' : 'Address',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lat,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lng,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await biz.saveBusinessProfile(
                  businessId: widget.businessId,
                  data: {
                    'nameEn': _nameEn.text.trim(),
                    'nameAr': _nameAr.text.trim(),
                    'descriptionEn': _descEn.text.trim(),
                    'descriptionAr': _descAr.text.trim(),
                    'phone': _phone.text.trim(),
                    'address': _address.text.trim(),
                    'latitude': double.tryParse(_lat.text.trim()) ?? 0,
                    'longitude': double.tryParse(_lng.text.trim()) ?? 0,
                    'provinceId': b?.provinceId ?? '',
                    'districtId': b?.districtId ?? '',
                    'subDistrictId': b?.subDistrictId ?? '',
                  },
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.isAr ? 'تم الحفظ' : 'Saved',
                    ),
                  ),
                );
              },
              child: Text(widget.isAr ? 'حفظ' : 'Save'),
            ),
          ],
        );
      },
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({required this.businessId, required this.isAr});
  final String businessId;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<AppState>().businessService;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: Text(isAr ? 'تصنيف جديد' : 'Add category'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BusinessCategory>>(
            stream: biz.watchCategories(businessId),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final c = items[i];
                  return ListTile(
                    title: Text(c.nameForLocale(isAr)),
                    subtitle: Text('order ${c.sortOrder}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _edit(context, c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => biz.deleteCategory(
                            businessId: businessId,
                            categoryId: c.id,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, BusinessCategory? existing) async {
    final en = TextEditingController(text: existing?.nameEn ?? '');
    final ar = TextEditingController(text: existing?.nameAr ?? '');
    final order = TextEditingController(
      text: '${existing?.sortOrder ?? 0}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تصنيف' : 'Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: en, decoration: const InputDecoration(labelText: 'EN')),
            TextField(controller: ar, decoration: const InputDecoration(labelText: 'AR')),
            TextField(
              controller: order,
              decoration: const InputDecoration(labelText: 'Sort order'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().businessService.saveCategory(
          businessId: businessId,
          categoryId: existing?.id,
          category: BusinessCategory(
            id: existing?.id ?? '',
            businessId: businessId,
            nameEn: en.text.trim(),
            nameAr: ar.text.trim(),
            sortOrder: int.tryParse(order.text.trim()) ?? 0,
          ),
        );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.businessId, required this.isAr});
  final String businessId;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<AppState>().businessService;
    const fare = FareService();
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: Text(isAr ? 'منتج جديد' : 'Add product'),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BusinessProduct>>(
            stream: biz.watchProducts(businessId),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final p = items[i];
                  return ListTile(
                    leading: p.imageUrl.isEmpty
                        ? const Icon(Icons.image_outlined)
                        : Image.network(p.imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                    title: Text(p.nameForLocale(isAr)),
                    subtitle: Text(
                      [
                        fare.formatIqd(p.effectivePriceIqd),
                        p.available
                            ? (isAr ? 'متاح' : 'available')
                            : (isAr ? 'غير متاح' : 'unavailable'),
                        '${p.prepMinutes}m',
                      ].join(' • '),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') await _edit(context, p);
                        if (v == 'dup') {
                          await biz.duplicateProduct(
                            businessId: businessId,
                            productId: p.id,
                          );
                        }
                        if (v == 'del') {
                          await biz.deleteProduct(
                            businessId: businessId,
                            productId: p.id,
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(isAr ? 'تعديل' : 'Edit')),
                        PopupMenuItem(value: 'dup', child: Text(isAr ? 'نسخ' : 'Duplicate')),
                        PopupMenuItem(value: 'del', child: Text(isAr ? 'حذف' : 'Delete')),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, BusinessProduct? existing) async {
    final categories = await context
        .read<AppState>()
        .businessService
        .watchCategories(businessId)
        .first;
    if (!context.mounted) return;
    final en = TextEditingController(text: existing?.nameEn ?? '');
    final ar = TextEditingController(text: existing?.nameAr ?? '');
    final price = TextEditingController(text: '${existing?.priceIqd ?? 0}');
    final discount =
        TextEditingController(text: '${existing?.discountPercent ?? 0}');
    final prep = TextEditingController(text: '${existing?.prepMinutes ?? 15}');
    var categoryId = existing?.categoryId ??
        (categories.isNotEmpty ? categories.first.id : '');
    var available = existing?.available ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isAr ? 'منتج' : 'Product'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: categoryId.isEmpty ? null : categoryId,
                      items: [
                        for (final c in categories)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nameForLocale(isAr)),
                          ),
                      ],
                      onChanged: (v) => setLocal(() => categoryId = v ?? ''),
                      decoration: InputDecoration(
                        labelText: isAr ? 'التصنيف' : 'Category',
                      ),
                    ),
                  TextField(controller: en, decoration: const InputDecoration(labelText: 'EN')),
                  TextField(controller: ar, decoration: const InputDecoration(labelText: 'AR')),
                  TextField(
                    controller: price,
                    decoration: InputDecoration(
                      labelText: isAr ? 'السعر' : 'Price IQD',
                    ),
                  ),
                  TextField(
                    controller: discount,
                    decoration: InputDecoration(
                      labelText: isAr ? 'خصم %' : 'Discount %',
                    ),
                  ),
                  TextField(
                    controller: prep,
                    decoration: InputDecoration(
                      labelText: isAr ? 'وقت التحضير (د)' : 'Prep minutes',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAr ? 'متاح' : 'Available'),
                    value: available,
                    onChanged: (v) => setLocal(() => available = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().businessService.saveProduct(
          businessId: businessId,
          productId: existing?.id,
          product: BusinessProduct(
            id: existing?.id ?? '',
            businessId: businessId,
            categoryId: categoryId,
            nameEn: en.text.trim(),
            nameAr: ar.text.trim(),
            priceIqd: int.tryParse(price.text.trim()) ?? 0,
            discountPercent: double.tryParse(discount.text.trim()) ?? 0,
            available: available,
            prepMinutes: int.tryParse(prep.text.trim()) ?? 15,
            imageUrl: existing?.imageUrl ?? '',
          ),
        );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.businessId, required this.isAr});
  final String businessId;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<AppState>().businessService;
    const fare = FareService();
    return StreamBuilder<List<BusinessOrder>>(
      stream: biz.watchOrdersForBusiness(businessId),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Center(child: Text(isAr ? 'لا طلبات' : 'No orders'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final o = items[i];
            return Card(
              child: ListTile(
                title: Text('${o.customerName} • ${fare.formatIqd(o.totalIqd)}'),
                subtitle: Text(
                  [
                    o.status.value,
                    ...o.items.map((e) => '${e.quantity}× ${isAr ? e.nameAr : e.nameEn}'),
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<BusinessOrderStatus>(
                  onSelected: (status) => biz.updateOrderStatus(
                    orderId: o.id,
                    status: status,
                  ),
                  itemBuilder: (_) => [
                    for (final s in [
                      BusinessOrderStatus.accepted,
                      BusinessOrderStatus.preparing,
                      BusinessOrderStatus.ready,
                      BusinessOrderStatus.rejected,
                      BusinessOrderStatus.cancelled,
                      BusinessOrderStatus.delivered,
                    ])
                      PopupMenuItem(value: s, child: Text(s.value)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
