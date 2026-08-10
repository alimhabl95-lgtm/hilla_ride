import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_wallet_screen.dart';
import 'package:provider/provider.dart';

class AdminWalletWithdrawalsTab extends StatefulWidget {
  const AdminWalletWithdrawalsTab({
    super.key,
    required this.fare,
    required this.isAr,
  });

  final FareService fare;
  final bool isAr;

  @override
  State<AdminWalletWithdrawalsTab> createState() =>
      _AdminWalletWithdrawalsTabState();
}

class _AdminWalletWithdrawalsTabState extends State<AdminWalletWithdrawalsTab> {
  String? _statusFilter;
  final _searchCtrl = TextEditingController();
  var _busyId = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _statusLabel(WalletWithdrawalStatus status) {
    final isAr = widget.isAr;
    return switch (status) {
      WalletWithdrawalStatus.pending => isAr ? 'قيد الانتظار' : 'Pending',
      WalletWithdrawalStatus.approved => isAr ? 'موافق عليه' : 'Approved',
      WalletWithdrawalStatus.processing => isAr ? 'قيد التحويل' : 'Processing',
      WalletWithdrawalStatus.completed => isAr ? 'مكتمل' : 'Completed',
      WalletWithdrawalStatus.rejected => isAr ? 'مرفوض' : 'Rejected',
      WalletWithdrawalStatus.cancelled => isAr ? 'ملغى' : 'Cancelled',
    };
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String requestId,
  }) async {
    setState(() => _busyId = requestId);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr ? 'تم التحديث' : 'Updated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyId = '');
    }
  }

  Future<String?> _askText({
    required String title,
    required String label,
    bool required = false,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (required && text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: Text(widget.isAr ? 'تأكيد' : 'Confirm'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _revealCard(WalletWithdrawalRequest req) async {
    try {
      final card = await context
          .read<AppState>()
          .walletService
          .getWithdrawalCardForAdmin(req.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(widget.isAr ? 'بطاقة ماستركارد' : 'Mastercard'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.isAr ? 'الاسم' : 'Name'}: ${card.cardholderName}'),
              const SizedBox(height: 8),
              SelectableText(
                card.cardNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: card.cardNumber));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(widget.isAr ? 'نسخ' : 'Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(widget.isAr ? 'إغلاق' : 'Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final wallet = context.watch<AppState>().walletService;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  value: _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: isAr ? 'الحالة' : 'Status',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(isAr ? 'الكل' : 'All'),
                    ),
                    for (final s in WalletWithdrawalStatus.values)
                      DropdownMenuItem(
                        value: s.value,
                        child: Text(_statusLabel(s)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: isAr ? 'بحث' : 'Search',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<WalletWithdrawalRequest>>(
            stream: wallet.watchWithdrawalRequests(status: _statusFilter),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final q = _searchCtrl.text.trim().toLowerCase();
              final items = snap.data!.where((r) {
                if (q.isEmpty) return true;
                return r.driverName.toLowerCase().contains(q) ||
                    r.driverPhone.contains(q) ||
                    r.referenceId.toLowerCase().contains(q) ||
                    r.cardLast4.contains(q) ||
                    r.driverId.toLowerCase().contains(q);
              }).toList();
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    isAr ? 'لا توجد طلبات سحب' : 'No withdrawal requests',
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final req = items[index];
                  final busy = _busyId == req.id;
                  final city = req.districtId.isEmpty
                      ? (isAr ? 'بدون مدينة' : 'No city')
                      : ServiceAreaCatalog.instance.localizedDistrictName(
                          req.districtId,
                          isAr: isAr,
                        );
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  req.driverName.isEmpty
                                      ? req.driverId
                                      : req.driverName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Chip(label: Text(_statusLabel(req.status))),
                            ],
                          ),
                          Text(req.driverPhone),
                          Text(city),
                          Text(
                            '${widget.fare.formatIqd(req.amountIqd)} • **** ${req.cardLast4}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${isAr ? 'الاسم على البطاقة' : 'Cardholder'}: ${req.cardholderName}',
                          ),
                          if (req.referenceId.isNotEmpty)
                            Text(
                              '${isAr ? 'المرجع' : 'Ref'}: ${req.referenceId}',
                            ),
                          if (req.rejectionReason.isNotEmpty)
                            Text(
                              '${isAr ? 'سبب الرفض' : 'Rejection'}: ${req.rejectionReason}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (req.adminNote.isNotEmpty)
                            Text(
                              '${isAr ? 'ملاحظة' : 'Note'}: ${req.adminNote}',
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: busy ? null : () => _revealCard(req),
                                icon: const Icon(Icons.credit_card),
                                label: Text(isAr ? 'إظهار البطاقة' : 'Reveal card'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminDriverWalletScreen(
                                        driverId: req.driverId,
                                        driverName: req.driverName,
                                        driverPhone: req.driverPhone,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(isAr ? 'محفظة السائق' : 'Driver wallet'),
                              ),
                              if (req.status == WalletWithdrawalStatus.pending)
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _runAction(
                                            () => wallet.reviewWithdrawalRequest(
                                              requestId: req.id,
                                              action: 'approve',
                                            ),
                                            requestId: req.id,
                                          ),
                                  child: Text(isAr ? 'موافقة' : 'Approve'),
                                ),
                              if (req.status ==
                                      WalletWithdrawalStatus.pending ||
                                  req.status ==
                                      WalletWithdrawalStatus.approved ||
                                  req.status ==
                                      WalletWithdrawalStatus.processing)
                                OutlinedButton(
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final reason = await _askText(
                                            title: isAr ? 'رفض السحب' : 'Reject',
                                            label: isAr
                                                ? 'سبب الرفض'
                                                : 'Rejection reason',
                                            required: true,
                                          );
                                          if (reason == null) return;
                                          await _runAction(
                                            () => wallet.reviewWithdrawalRequest(
                                              requestId: req.id,
                                              action: 'reject',
                                              rejectionReason: reason,
                                            ),
                                            requestId: req.id,
                                          );
                                        },
                                  child: Text(isAr ? 'رفض' : 'Reject'),
                                ),
                              if (req.status == WalletWithdrawalStatus.approved)
                                FilledButton.tonal(
                                  onPressed: busy
                                      ? null
                                      : () => _runAction(
                                            () => wallet.processWithdrawalRequest(
                                              requestId: req.id,
                                            ),
                                            requestId: req.id,
                                          ),
                                  child: Text(isAr ? 'بدء التحويل' : 'Process'),
                                ),
                              if (req.status ==
                                      WalletWithdrawalStatus.processing ||
                                  req.status == WalletWithdrawalStatus.approved)
                                FilledButton(
                                  onPressed: busy
                                      ? null
                                      : () => _runAction(
                                            () => wallet.completeWithdrawalRequest(
                                              requestId: req.id,
                                            ),
                                            requestId: req.id,
                                          ),
                                  child: Text(isAr ? 'إتمام' : 'Complete'),
                                ),
                              if (busy)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
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
}
