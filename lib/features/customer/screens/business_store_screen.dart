import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Store detail — categories, products, prices, discounts, images from Firestore.
class BusinessStoreScreen extends StatefulWidget {
  const BusinessStoreScreen({
    super.key,
    required this.user,
    required this.businessId,
  });

  final AppUser user;
  final String businessId;

  @override
  State<BusinessStoreScreen> createState() => _BusinessStoreScreenState();
}

class _BusinessStoreScreenState extends State<BusinessStoreScreen> {
  final Map<String, int> _cartQty = {};
  final Map<String, BusinessProduct> _cartProducts = {};
  String? _categoryFilter;
  var _placing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final biz = context.watch<AppState>().businessService;
    const fare = FareService();

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<BusinessPartner?>(
          stream: biz.watchBusiness(widget.businessId),
          builder: (context, snap) {
            final b = snap.data;
            if (b != null && !b.isLive) {
              return Text(isAr ? 'غير متاح' : 'Unavailable');
            }
            return Text(
              b?.nameForLocale(isAr) ?? (isAr ? 'المتجر' : 'Store'),
            );
          },
        ),
      ),
      body: StreamBuilder<BusinessPartner?>(
        stream: biz.watchBusiness(widget.businessId),
        builder: (context, bizSnap) {
          final partner = bizSnap.data;
          if (partner != null && !partner.isLive) {
            return Center(
              child: Text(
                isAr
                    ? 'هذا المتجر غير مباشر حالياً'
                    : 'This store is not live right now',
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (partner != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    [
                      if (partner.address.isNotEmpty) partner.address,
                      '★ ${partner.rating.toStringAsFixed(1)}'
                          ' (${partner.ratingCount})',
                    ].join(' • '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              StreamBuilder<List<BusinessCategory>>(
                stream: biz.watchCategories(widget.businessId),
                builder: (context, catSnap) {
                  final categories = (catSnap.data ?? const [])
                      .where((c) => c.active)
                      .toList();
                  if (categories.isEmpty) {
                    return const SizedBox(height: 4);
                  }
                  return SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            label: Text(isAr ? 'الكل' : 'All'),
                            selected: _categoryFilter == null,
                            onSelected: (_) =>
                                setState(() => _categoryFilter = null),
                          ),
                        ),
                        for (final c in categories)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: FilterChip(
                              label: Text(c.nameForLocale(isAr)),
                              selected: _categoryFilter == c.id,
                              onSelected: (_) =>
                                  setState(() => _categoryFilter = c.id),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: StreamBuilder<List<BusinessProduct>>(
                  stream: biz.watchProducts(
                    widget.businessId,
                    categoryId: _categoryFilter,
                  ),
                  builder: (context, snap) {
                    final products = (snap.data ?? const [])
                        .where((p) => p.available)
                        .toList();
                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          isAr ? 'لا منتجات متاحة' : 'No products available',
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: products.length,
                      itemBuilder: (context, i) {
                        final p = products[i];
                        final qty = _cartQty[p.id] ?? 0;
                        return ListTile(
                          leading: p.imageUrl.isEmpty
                              ? const Icon(Icons.fastfood_outlined)
                              : Image.network(
                                  p.imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                          title: Text(p.nameForLocale(isAr)),
                          subtitle: Text(
                            [
                              fare.formatIqd(p.effectivePriceIqd),
                              if (p.discountPercent > 0)
                                '-${p.discountPercent.toStringAsFixed(0)}%',
                              '${p.prepMinutes} ${isAr ? 'د' : 'min'}',
                            ].join(' • '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: qty <= 0
                                    ? null
                                    : () => setState(() {
                                          final next = qty - 1;
                                          if (next <= 0) {
                                            _cartQty.remove(p.id);
                                            _cartProducts.remove(p.id);
                                          } else {
                                            _cartQty[p.id] = next;
                                          }
                                        }),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$qty'),
                              IconButton(
                                onPressed: () => setState(() {
                                  _cartQty[p.id] = qty + 1;
                                  _cartProducts[p.id] = p;
                                }),
                                icon: const Icon(Icons.add_circle_outline),
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
        },
      ),
      bottomNavigationBar: _cartQty.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _placing ? null : () => _checkout(isAr),
                  child: Text(
                    _placing
                        ? (isAr ? 'جارٍ الطلب...' : 'Placing...')
                        : (isAr
                            ? 'اطلب الآن (${_cartQty.values.fold(0, (a, b) => a + b)})'
                            : 'Place order (${_cartQty.values.fold(0, (a, b) => a + b)})'),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _checkout(bool isAr) async {
    setState(() => _placing = true);
    try {
      final items = <BusinessOrderItem>[
        for (final e in _cartQty.entries)
          if (_cartProducts[e.key] != null)
            BusinessOrderItem(
              productId: e.key,
              nameEn: _cartProducts[e.key]!.nameEn,
              nameAr: _cartProducts[e.key]!.nameAr,
              unitPriceIqd: _cartProducts[e.key]!.effectivePriceIqd,
              quantity: e.value,
            ),
      ];
      final businessService = context.read<AppState>().businessService;
      final business = await businessService.watchBusiness(widget.businessId).first;
      if (business == null || !business.isLive) {
        throw Exception(
          isAr ? 'المتجر غير مباشر' : 'Store is not live',
        );
      }
      final orderId = await businessService.placeOrder(
        businessId: widget.businessId,
        items: items,
        dropoffLat: business.latitude,
        dropoffLng: business.longitude,
        dropoffLabel: isAr ? 'عنوان التوصيل' : 'Delivery address',
        notes: '',
      );
      if (!mounted) return;
      setState(() {
        _cartQty.clear();
        _cartProducts.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم إرسال الطلب: $orderId' : 'Order placed: $orderId',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}
