import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_detail_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminBonusesPanel extends StatefulWidget {
  const AdminBonusesPanel({super.key});

  @override
  State<AdminBonusesPanel> createState() => _AdminBonusesPanelState();
}

class _AdminBonusesPanelState extends State<AdminBonusesPanel> {
  var _actionBonusId = '';

  Future<void> _grantBonus(DriverProfile driver) async {
    final l10n = AppLocalizations.of(context)!;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final auth = context.read<AppState>().authService.currentUser;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.grantBonusTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.grantBonusHint(driver.name)),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.bonusAmountLabel,
                suffixText: 'IQD',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(labelText: l10n.bonusReasonLabel),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.grantBonusAction),
          ),
        ],
      ),
    );

    if (confirmed != true || auth == null) {
      amountController.dispose();
      reasonController.dispose();
      return;
    }

    if (!mounted) {
      amountController.dispose();
      reasonController.dispose();
      return;
    }

    final adminService = context.read<AppState>().adminService;
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final reason = reasonController.text.trim();
    amountController.dispose();
    reasonController.dispose();

    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bonusAmountInvalid)),
      );
      return;
    }

    try {
      await adminService.grantDriverBonus(
            driverId: driver.uid,
            amountIqd: amount,
            reason: reason,
            grantedByUid: auth.uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bonusGranted)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _markBonusPaid(DriverBonus bonus) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _actionBonusId = bonus.id);
    try {
      await context.read<AppState>().adminService.markBonusPaid(
            driverId: bonus.driverId,
            bonusId: bonus.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bonusMarkedPaid)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _actionBonusId = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final adminService = context.read<AppState>().adminService;

    return StreamBuilder<List<DriverProfile>>(
      stream: adminService.watchAllDrivers(),
      builder: (context, driversSnapshot) {
        final drivers = driversSnapshot.data ?? const [];
        final driverNames = {
          for (final driver in drivers) driver.uid: driver.name,
        };

        return StreamBuilder<List<DriverBonus>>(
          stream: adminService.watchAllDriverBonuses(),
          builder: (context, bonusesSnapshot) {
            final bonuses = bonusesSnapshot.data ?? const [];
            final pendingBonuses =
                bonuses.where((bonus) => !bonus.isPaid).toList();

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.driverBonusesTab,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(l10n.driverBonusesHint),
                const SizedBox(height: 24),
                Text(
                  l10n.grantBonusQuickTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (drivers.isEmpty)
                  Text(l10n.noDriversYet)
                else
                  ...drivers.map((driver) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.card_giftcard_outlined),
                        title: Text(driver.name),
                        subtitle: Text(
                          '${l10n.pendingBonusLabel}: ${fareService.formatIqd(driver.pendingBonusIqd, locale: l10n.localeName)}',
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () => _grantBonus(driver),
                          child: Text(l10n.grantBonusAction),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminDriverDetailScreen(driver: driver),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Text(
                  l10n.pendingBonusesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (pendingBonuses.isEmpty)
                  Text(l10n.noPendingBonuses)
                else
                  ...pendingBonuses.map((bonus) {
                    final date = bonus.createdAt;
                    final dateLabel = date == null
                        ? ''
                        : DateFormat.yMMMd(l10n.localeName).add_jm().format(date);
                    final driverName =
                        driverNames[bonus.driverId] ?? bonus.driverId;

                    return Card(
                      child: ListTile(
                        title: Text(driverName),
                        subtitle: Text(
                          [
                            fareService.formatIqd(
                              bonus.amountIqd,
                              locale: l10n.localeName,
                            ),
                            if (bonus.reason.isNotEmpty) bonus.reason,
                            if (dateLabel.isNotEmpty) dateLabel,
                          ].join(' • '),
                        ),
                        trailing: _actionBonusId == bonus.id
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : FilledButton(
                                onPressed: () => _markBonusPaid(bonus),
                                child: Text(l10n.markBonusPaid),
                              ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}
