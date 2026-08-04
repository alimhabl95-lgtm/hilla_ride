import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminDriverWalletScreen extends StatefulWidget {
  const AdminDriverWalletScreen({
    super.key,
    required this.driverId,
    this.driverName = '',
    this.driverPhone = '',
  });

  final String driverId;
  final String driverName;
  final String driverPhone;

  @override
  State<AdminDriverWalletScreen> createState() =>
      _AdminDriverWalletScreenState();
}

class _AdminDriverWalletScreenState extends State<AdminDriverWalletScreen> {
  static const _fare = FareService();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _adjust(bool isAr) async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final note = _noteCtrl.text.trim();
    if (amount == 0 || note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'أدخل المبلغ والملاحظة'
                : 'Enter amount and note',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().walletService.adjustWallet(
            driverId: widget.driverId,
            amountIqd: amount,
            note: note,
          );
      if (!mounted) return;
      _amountCtrl.clear();
      _noteCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم تعديل الرصيد' : 'Wallet adjusted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final title = widget.driverName.isNotEmpty
        ? widget.driverName
        : (isAr ? 'محفظة السائق' : 'Driver wallet');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<DriverProfile?>(
        stream:
            context.read<AppState>().driverService.watchDriver(widget.driverId),
        builder: (context, driverSnap) {
          final driver = driverSnap.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.driverName.isNotEmpty
                            ? widget.driverName
                            : widget.driverId,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.driverPhone.isNotEmpty)
                        Text(widget.driverPhone),
                      Text(
                        widget.driverId,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAr ? 'الرصيد الحالي' : 'Current balance',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        _fare.formatIqd(
                          driver?.walletBalanceIqd ?? 0,
                          locale: l10n.localeName,
                        ),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF0F766E),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${isAr ? 'الحالة' : 'Status'}: ${driver?.walletStatus ?? '—'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAr ? 'تعديل سريع' : 'Quick adjust',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'موجب = إضافة، سالب = خصم'
                    : 'Positive = credit, negative = debit',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isAr ? 'المبلغ (د.ع)' : 'Amount (IQD)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: isAr ? 'ملاحظة (مطلوبة)' : 'Note (required)',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : () => _adjust(isAr),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isAr ? 'تطبيق' : 'Apply'),
              ),
              const SizedBox(height: 24),
              Text(
                isAr ? 'سجل المحفظة' : 'Wallet ledger',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<WalletLedgerEntry>>(
                stream: context
                    .read<AppState>()
                    .walletService
                    .watchLedger(widget.driverId),
                builder: (context, snap) {
                  final entries = snap.data ?? const [];
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (entries.isEmpty) {
                    return Text(
                      isAr ? 'لا توجد عمليات بعد' : 'No ledger entries yet',
                    );
                  }
                  return Column(
                    children: [
                      for (final e in entries) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            e.amountIqd >= 0
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: e.amountIqd >= 0 ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            switch (e.type) {
                              WalletLedgerType.recharge =>
                                isAr ? 'شحن' : 'Recharge',
                              WalletLedgerType.commission =>
                                isAr ? 'عمولة' : 'Commission',
                              WalletLedgerType.adjustment =>
                                isAr ? 'تعديل' : 'Adjustment',
                              WalletLedgerType.refund =>
                                isAr ? 'استرداد' : 'Refund',
                              WalletLedgerType.bonus =>
                                isAr ? 'مكافأة' : 'Bonus',
                              WalletLedgerType.penalty =>
                                isAr ? 'غرامة' : 'Penalty',
                              WalletLedgerType.reward =>
                                isAr ? 'حافز / مكافأة' : 'Reward',
                            },
                          ),
                          subtitle: Text(
                            [
                              if (e.note.isNotEmpty) e.note,
                              if (e.createdAt != null)
                                e.createdAt!
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16),
                              '${isAr ? 'بعدها' : 'After'}: ${_fare.formatIqd(e.balanceAfterIqd, locale: l10n.localeName)}',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            '${e.amountIqd >= 0 ? '+' : ''}${_fare.formatIqd(e.amountIqd, locale: l10n.localeName)}',
                            style: TextStyle(
                              color:
                                  e.amountIqd >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
