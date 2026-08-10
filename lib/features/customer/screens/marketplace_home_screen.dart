import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
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
                      return AppEmptyState(
                        title: isAr ? 'لا متاجر مباشرة حالياً' : 'No live businesses yet',
                        message: isAr
                            ? 'ستظهر تلقائياً عند موافقة الإدارة'
                            : 'They appear automatically when approved',
                        icon: Icons.storefront_outlined,
                      );
                    }
                return StreamBuilder<Set<String>>(
                  stream: context
                      .read<AppState>()
                      .savedPlacesService
                      .watchFavoriteBusinessIds(widget.user.uid),
                  builder: (context, favSnap) {
                    final favorites = favSnap.data ?? const {};
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final b = items[i];
                        final isFavorite = favorites.contains(b.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
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
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: b.logoUrl.isNotEmpty
                                      ? NetworkImage(b.logoUrl)
                                      : null,
                                  child: b.logoUrl.isEmpty
                                      ? const Icon(Icons.storefront)
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.nameForLocale(isAr),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          typeNames[b.typeId] ?? b.typeId,
                                          if (b.address.isNotEmpty) b.address,
                                          '★ ${b.rating.toStringAsFixed(1)}',
                                        ].join(' • '),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: isFavorite
                                      ? (isAr ? 'إزالة من المفضلة' : 'Remove favorite')
                                      : (isAr ? 'إضافة للمفضلة' : 'Add favorite'),
                                  icon: Icon(
                                    isFavorite ? Icons.favorite : Icons.favorite_border,
                                    color: isFavorite
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                                  onPressed: () {
                                    context
                                        .read<AppState>()
                                        .savedPlacesService
                                        .toggleFavoriteBusiness(
                                          uid: widget.user.uid,
                                          businessId: b.id,
                                        );
                                  },
                                ),
                                const Icon(Icons.chevron_right, size: 22),
                              ],
                            ),
                          ),
                        );
                      },
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
