import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_detail_screen.dart';
import 'package:hilla_ride/features/admin/screens/admin_ride_detail_screen.dart';
import 'package:provider/provider.dart';

enum AdminSearchResultType {
  driver,
  customer,
  business,
  ride,
  businessOrder,
}

class AdminSearchResult {
  const AdminSearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.driver,
    this.customer,
    this.business,
    this.ride,
    this.order,
  });

  final AdminSearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final DriverProfile? driver;
  final AppUser? customer;
  final BusinessPartner? business;
  final Ride? ride;
  final BusinessOrder? order;
}

class AdminGlobalSearch {
  AdminGlobalSearch({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<AdminSearchResult>> search({
    required String query,
    required AppState appState,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];

    final results = <AdminSearchResult>[];

    void add(AdminSearchResult item) {
      if (results.length >= limit) return;
      if (results.any((r) => r.type == item.type && r.id == item.id)) return;
      results.add(item);
    }

    bool matchesText(String value) => value.toLowerCase().contains(q);

    final drivers = await appState.adminService.watchAllDrivers().first;
    for (final driver in drivers) {
      if (results.length >= limit) break;
      if (matchesText('${driver.name} ${driver.phone} ${driver.uid}')) {
        add(
          AdminSearchResult(
            type: AdminSearchResultType.driver,
            id: driver.uid,
            title: driver.name,
            subtitle: driver.phone,
            driver: driver,
          ),
        );
      }
    }

    final customers = await appState.adminService.watchCustomers().first;
    for (final customer in customers) {
      if (results.length >= limit) break;
      if (matchesText('${customer.name} ${customer.phone} ${customer.uid}')) {
        add(
          AdminSearchResult(
            type: AdminSearchResultType.customer,
            id: customer.uid,
            title: customer.name,
            subtitle: customer.phone,
            customer: customer,
          ),
        );
      }
    }

    final businesses =
        await appState.businessService.watchBusinesses(limit: 500).first;
    for (final business in businesses) {
      if (results.length >= limit) break;
      if (matchesText(
        '${business.nameEn} ${business.nameAr} ${business.phone} ${business.id}',
      )) {
        add(
          AdminSearchResult(
            type: AdminSearchResultType.business,
            id: business.id,
            title: business.nameEn,
            subtitle: business.phone.isNotEmpty ? business.phone : business.id,
            business: business,
          ),
        );
      }
    }

    if (q.length >= 3) {
      final ridePrefix = q.toUpperCase();
      final rideSnap = await _firestore
          .collection('rides')
          .orderBy(FieldPath.documentId)
          .startAt([ridePrefix])
          .endAt(['$ridePrefix\uf8ff'])
          .limit(limit)
          .get();
      for (final doc in rideSnap.docs) {
        if (results.length >= limit) break;
        final ride = Ride.fromMap(doc.id, doc.data());
        add(
          AdminSearchResult(
            type: AdminSearchResultType.ride,
            id: ride.id,
            title: ride.id,
            subtitle: '${ride.status.value} • ${ride.customerId}',
            ride: ride,
          ),
        );
      }

      final orderSnap = await _firestore
          .collection('businessOrders')
          .orderBy(FieldPath.documentId)
          .startAt([ridePrefix])
          .endAt(['$ridePrefix\uf8ff'])
          .limit(limit)
          .get();
      for (final doc in orderSnap.docs) {
        if (results.length >= limit) break;
        final order = BusinessOrder.fromDoc(doc);
        add(
          AdminSearchResult(
            type: AdminSearchResultType.businessOrder,
            id: order.id,
            title: order.id,
            subtitle: '${order.status.value} • ${order.businessName}',
            order: order,
          ),
        );
      }
    }

    return results;
  }
}

class AdminGlobalSearchField extends StatefulWidget {
  const AdminGlobalSearchField({super.key, this.compact = false});

  final bool compact;

  static void navigateToResult(
    BuildContext context,
    AdminSearchResult result,
  ) =>
      _navigateAdminSearchResult(context, result);

  @override
  State<AdminGlobalSearchField> createState() => _AdminGlobalSearchFieldState();
}

void _navigateAdminSearchResult(
  BuildContext context,
  AdminSearchResult result,
) {
  switch (result.type) {
    case AdminSearchResultType.driver:
      final driver = result.driver;
      if (driver == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminDriverDetailScreen(driver: driver),
        ),
      );
    case AdminSearchResultType.customer:
      final customer = result.customer;
      if (customer == null) return;
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
          return AlertDialog(
            title: Text(customer.name),
            content: Text(
              '${customer.phone}\n${customer.uid}\n'
              '${isAr ? 'ملغاة' : 'Cancelled'}: ${customer.cancelledRidesCount}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? 'إغلاق' : 'Close'),
              ),
            ],
          );
        },
      );
    case AdminSearchResultType.business:
      final business = result.business;
      if (business == null) return;
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
          return AlertDialog(
            title: Text(business.nameForLocale(isAr)),
            content: Text(
              '${business.phone}\n${business.id}\n${business.status.value}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? 'إغلاق' : 'Close'),
              ),
            ],
          );
        },
      );
    case AdminSearchResultType.ride:
      final ride = result.ride;
      if (ride == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminRideDetailScreen(ride: ride),
        ),
      );
    case AdminSearchResultType.businessOrder:
      final order = result.order;
      if (order == null) return;
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final isAr = Localizations.localeOf(ctx).languageCode == 'ar';
          return AlertDialog(
            title: Text(order.id),
            content: Text(
              '${order.businessName}\n${order.status.value}\n'
              '${order.totalIqd} IQD',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isAr ? 'إغلاق' : 'Close'),
              ),
            ],
          );
        },
      );
  }
}

class _AdminGlobalSearchFieldState extends State<AdminGlobalSearchField> {
  final _search = AdminGlobalSearch();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _openSearchSheet() async {
    final controller = TextEditingController();
    var results = <AdminSearchResult>[];
    var isSearching = false;

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onChanged(String value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () async {
                final trimmed = value.trim();
                if (trimmed.length < 2) {
                  setSheetState(() {
                    results = const [];
                    isSearching = false;
                  });
                  return;
                }
                setSheetState(() => isSearching = true);
                try {
                  final found = await _search.search(
                    query: trimmed,
                    appState: sheetContext.read<AppState>(),
                  );
                  setSheetState(() {
                    results = found;
                    isSearching = false;
                  });
                } catch (_) {
                  setSheetState(() => isSearching = false);
                }
              });
            }

            final isAr =
                Localizations.localeOf(sheetContext).languageCode == 'ar';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        autofocus: true,
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: isAr
                              ? 'بحث سائق، زبون، متجر، رحلة…'
                              : 'Search driver, customer, store, ride…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    controller.clear();
                                    onChanged('');
                                  },
                                ),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: onChanged,
                      ),
                    ),
                    Expanded(
                      child: _SearchResultsList(
                        query: controller.text,
                        results: results,
                        isSearching: isSearching,
                        onTap: (result) {
                          Navigator.pop(sheetContext);
                          AdminGlobalSearchField.navigateToResult(
                            this.context,
                            result,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      return IconButton(
        tooltip: isAr ? 'بحث' : 'Search',
        icon: const Icon(Icons.search),
        onPressed: _openSearchSheet,
      );
    }

    return SizedBox(
      width: 360,
      child: _InlineAdminSearch(
        onNavigate: (result) =>
            AdminGlobalSearchField.navigateToResult(context, result),
      ),
    );
  }
}

class _InlineAdminSearch extends StatefulWidget {
  const _InlineAdminSearch({required this.onNavigate});

  final ValueChanged<AdminSearchResult> onNavigate;

  @override
  State<_InlineAdminSearch> createState() => _InlineAdminSearchState();
}

class _InlineAdminSearchState extends State<_InlineAdminSearch> {
  final _controller = TextEditingController();
  final _search = AdminGlobalSearch();
  Timer? _debounce;
  var _isSearching = false;
  List<AdminSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final trimmed = value.trim();
      if (trimmed.length < 2) {
        if (mounted) setState(() => _results = const []);
        return;
      }
      if (mounted) setState(() => _isSearching = true);
      try {
        final results = await _search.search(
          query: trimmed,
          appState: context.read<AppState>(),
        );
        if (mounted) {
          setState(() {
            _results = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: isAr ? 'بحث…' : 'Search…',
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: _onChanged,
        ),
        if (_results.isNotEmpty)
          Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    dense: true,
                    title: Text(result.title, maxLines: 1),
                    subtitle: Text(result.subtitle, maxLines: 1),
                    onTap: () => widget.onNavigate(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.query,
    required this.results,
    required this.isSearching,
    required this.onTap,
  });

  final String query;
  final List<AdminSearchResult> results;
  final bool isSearching;
  final ValueChanged<AdminSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    if (query.trim().length < 2) {
      return Center(
        child: Text(isAr ? 'اكتب حرفين على الأقل' : 'Type at least 2 characters'),
      );
    }
    if (results.isEmpty && !isSearching) {
      return Center(child: Text(isAr ? 'لا نتائج' : 'No results'));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = results[index];
        final label = switch (result.type) {
          AdminSearchResultType.driver => isAr ? 'سائق' : 'Driver',
          AdminSearchResultType.customer => isAr ? 'زبون' : 'Customer',
          AdminSearchResultType.business => isAr ? 'متجر' : 'Business',
          AdminSearchResultType.ride => isAr ? 'رحلة' : 'Ride',
          AdminSearchResultType.businessOrder => isAr ? 'طلب' : 'Order',
        };
        return ListTile(
          leading: Chip(
            label: Text(label, style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              Text(result.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => onTap(result),
        );
      },
    );
  }
}
