import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class CustomerRewardsScreen extends StatelessWidget {
  const CustomerRewardsScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rewardsTitle)),
      backgroundColor: AppBrandAssets.brandSurface,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rewardsOffersHeading,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppBrandAssets.brandNavy,
                      ),
                ),
                const SizedBox(height: 8),
                if (user.hasActivePromo)
                  Text(
                    l10n.customerPromoBanner(
                      user.promoCode,
                      (user.promoRidesLimit - user.promoRidesUsed).clamp(0, 999),
                    ),
                    style: const TextStyle(color: AppBrandAssets.brandTealDark),
                  )
                else if (user.promoCode.isNotEmpty)
                  Text(
                    l10n.rewardsPromoUsed(user.promoCode),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  )
                else
                  Text(
                    l10n.rewardsEmptyHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.rewardsFooterHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}

class CustomerRewardsRoute extends StatelessWidget {
  const CustomerRewardsRoute({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<AppUser?>(
      stream: context.read<AppState>().authService.watchUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.rewardsTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return CustomerRewardsScreen(user: user);
      },
    );
  }
}
