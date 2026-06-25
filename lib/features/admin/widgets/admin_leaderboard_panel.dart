import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminLeaderboardPanel extends StatefulWidget {
  const AdminLeaderboardPanel({super.key});

  @override
  State<AdminLeaderboardPanel> createState() => _AdminLeaderboardPanelState();
}

class _AdminLeaderboardPanelState extends State<AdminLeaderboardPanel> {
  var _isResetting = false;
  var _actionDriverId = '';

  Future<void> _markWinner(String driverId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _actionDriverId = driverId);
    try {
      await context.read<AppState>().monthlyPrizeService.markWinner(driverId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leaderboardWinnerMarked)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _actionDriverId = '');
    }
  }

  Future<void> _markPaid() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isResetting = true);
    try {
      await context.read<AppState>().monthlyPrizeService.markPaid();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leaderboardPaidMarked)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  Future<void> _resetMonthly() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetMonthlyCounter),
        content: Text(l10n.resetMonthlyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.resetMonthlyCounter),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    try {
      await context.read<AppState>().monthlyPrizeService.resetMonthlyCounter();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.leaderboardResetDone)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final monthlyPrizeService = context.read<AppState>().monthlyPrizeService;

    return StreamBuilder<MonthlyPrizeConfig>(
      stream: monthlyPrizeService.watchConfig(),
      builder: (context, configSnapshot) {
        final config = configSnapshot.data ??
            MonthlyPrizeConfig(
              prizeAmountIqd: MonthlyPrizeConfig.defaultPrizeIqd,
              monthKey: MonthlyPrizeConfig.currentMonthKey(),
            );

        return StreamBuilder<List<MonthlyLeaderboardEntry>>(
          stream: monthlyPrizeService.watchLeaderboard(),
          builder: (context, leaderboardSnapshot) {
            final entries = leaderboardSnapshot.data ?? const [];
            final topEntry = entries.isNotEmpty ? entries.first : null;
            final hasWinner = config.winnerDriverId.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.monthlyLeaderboardTab,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.monthlyLeaderboardMonth(config.monthKey),
                ),
                Text(
                  l10n.monthlyPrizeAmount(
                    fareService.formatIqd(
                      config.prizeAmountIqd,
                      locale: l10n.localeName,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (hasWinner && !config.winnerPaid)
                      FilledButton.icon(
                        onPressed: _isResetting ? null : _markPaid,
                        icon: const Icon(Icons.paid_outlined),
                        label: Text(l10n.markAsPaid),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isResetting ? null : _resetMonthly,
                      icon: _isResetting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.resetMonthlyCounter),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (entries.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.leaderboardEmpty),
                    ),
                  )
                else
                  ...entries.map((entry) {
                    final isTop = entry.rank == 1;
                    final isBusy = _actionDriverId == entry.driverId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  child: Text('#${entry.rank}'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(entry.phone),
                                      Text(
                                        l10n.leaderboardRideCount(entry.rideCount),
                                      ),
                                    ],
                                  ),
                                ),
                                if (entry.isWinner)
                                  Chip(
                                    label: Text(l10n.leaderboardWinnerBadge),
                                    backgroundColor:
                                        Colors.amber.withValues(alpha: 0.2),
                                  ),
                                if (entry.isPaid)
                                  Chip(
                                    label: Text(l10n.leaderboardPaidBadge),
                                    backgroundColor:
                                        Colors.green.withValues(alpha: 0.2),
                                  ),
                              ],
                            ),
                            if (isTop && !entry.isWinner) ...[
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: isBusy ? null : () => _markWinner(entry.driverId),
                                child: isBusy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.markAsWinner),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                if (topEntry != null && topEntry.isWinner)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.leaderboardCurrentWinner(topEntry.name),
                      style: Theme.of(context).textTheme.titleMedium,
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
