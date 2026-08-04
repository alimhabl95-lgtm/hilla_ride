import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/customer/screens/business_store_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

/// Live marketplace — all data from Firestore, no hardcoded businesses.
class MarketplaceHomeScreen extends StatefulWidget {
  const MarketplaceHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MarketplaceHomeScreen> createState() => _MarketplaceHomeScreenState();
}

class _MarketplaceHomeScreenState extends State<MarketplaceHomeScreen> {
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final biz = context.watch<AppState>().businessService;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'المتاجر والخدمات' : 'Stores & services'),
      ),
      body: Column(
        children: [
          StreamBuilder<List<BusinessTypeConfig>>(
            stream: biz.watchBusinessTypes(),
            builder: (context, snap) {
              final types = snap.data ?? const [];
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        label: Text(isAr ? 'الكل' : 'All'),
                        selected: _typeFilter == null,
                        onSelected: (_) => setState(() => _typeFilter = null),
                      ),
                    ),
                    for (final t in types)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          label: Text(t.nameForLocale(isAr)),
                          selected: _typeFilter == t.id,
                          onSelected: (_) =>
                              setState(() => _typeFilter = t.id),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<BusinessTypeConfig>>(
              stream: biz.watchBusinessTypes(),
              builder: (context, typeSnap) {
                final typeNames = {
                  for (final t in typeSnap.data ?? const <BusinessTypeConfig>[])
                    t.id: t.nameForLocale(isAr),
                };
                return StreamBuilder<List<BusinessPartner>>(
                  stream: biz.watchLiveBusinesses(typeId: _typeFilter),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('${snap.error}'));
                    }
                    final items = snap.data ?? const [];
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          isAr
                              ? 'لا متاجر مباشرة حالياً — ستظهر تلقائياً عند موافقة الإدارة'
                              : 'No live businesses yet — they appear automatically when approved',
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final b = items[i];
                        return Card(
                          child: ListTile(
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
                                typeNames[b.typeId] ?? b.typeId,
                                if (b.address.isNotEmpty) b.address,
                                '★ ${b.rating.toStringAsFixed(1)}',
                              ].join(' • '),
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BusinessStoreScreen(
                                    user: widget.user,
                                    businessId: b.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
