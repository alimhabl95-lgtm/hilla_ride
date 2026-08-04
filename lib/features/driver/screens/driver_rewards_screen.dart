import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/reward_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class DriverRewardsScreen extends StatelessWidget {
  const DriverRewardsScreen({super.key, required this.driver});

  final DriverProfile driver;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final rewards = context.watch<AppState>().rewardService;
    const fare = FareService();

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'المكافآت' : 'Rewards'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            isAr ? 'الحملات النشطة' : 'Active campaigns',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<RewardCampaign>>(
            stream: rewards.watchActiveCampaigns(),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return Text(
                  isAr
                      ? 'لا توجد حملات مكافآت حالياً'
                      : 'No active reward campaigns right now',
                );
              }
              return Column(
                children: items
                    .map(
                      (c) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.emoji_events_outlined),
                          title: Text(c.titleForLocale(isAr)),
                          subtitle: Text(
                            [
                              if (c.descriptionForLocale(isAr).isNotEmpty)
                                c.descriptionForLocale(isAr),
                              _driverRewardSummary(c.reward, isAr, fare),
                            ].where((e) => e.isNotEmpty).join('\n'),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            isAr ? 'مكافآتك' : 'Your rewards',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<RewardGrant>>(
            stream: rewards.watchDriverGrants(driver.uid),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return Text(
                  isAr
                      ? 'لم تحصل على مكافآت بعد — أكمل الرحلات لفتح الحملات'
                      : 'No rewards yet — complete trips to unlock campaigns',
                );
              }
              return Column(
                children: items
                    .map(
                      (g) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.card_giftcard),
                        title: Text(g.titleForLocale(isAr)),
                        subtitle: Text(
                          [
                            g.rewardType,
                            if (g.amountIqd > 0) fare.formatIqd(g.amountIqd),
                            if (g.createdAt != null)
                              g.createdAt!.toLocal().toString().substring(0, 16),
                          ].join(' • '),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _driverRewardSummary(
  RewardPayload reward,
  bool isAr,
  FareService fare,
) {
  return switch (reward.type) {
    RewardType.walletCredit || RewardType.bonus =>
      '${isAr ? 'مكافأة محفظة' : 'Wallet reward'}: ${fare.formatIqd(reward.amountIqd)}',
    RewardType.commissionDiscount =>
      '${isAr ? 'خصم عمولة' : 'Commission discount'}: ${reward.commissionDiscountPercent.toStringAsFixed(0)}%',
    RewardType.freeTrips =>
      '${isAr ? 'رحلات بدون عمولة' : 'Commission-free trips'}: ${reward.freeTripsCount}',
    RewardType.custom => isAr ? 'مكافأة خاصة' : 'Special reward',
  };
}
