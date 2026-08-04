import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_wallet_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminWalletPanel extends StatefulWidget {
  const AdminWalletPanel({super.key});

  @override
  State<AdminWalletPanel> createState() => _AdminWalletPanelState();
}

class _AdminWalletPanelState extends State<AdminWalletPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _fare = FareService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: isAr ? 'طلبات الشحن' : 'Recharges'),
            Tab(text: isAr ? 'تعديل رصيد' : 'Adjust'),
            Tab(text: isAr ? 'الإعدادات' : 'Settings'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PendingRechargesTab(fare: _fare, isAr: isAr),
              _AdjustWalletTab(fare: _fare, isAr: isAr),
              _WalletSettingsTab(isAr: isAr),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingRechargesTab extends StatelessWidget {
  const _PendingRechargesTab({required this.fare, required this.isAr});

  final FareService fare;
  final bool isAr;

  void _openDriverWallet(BuildContext context, WalletRechargeRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDriverWalletScreen(
          driverId: request.driverId,
          driverName: request.driverName,
          driverPhone: request.driverPhone,
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context, {
    required WalletRechargeRequest request,
    required bool approve,
  }) async {
    var reason = '';
    int? approvedAmount;
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isAr ? 'سبب الرفض' : 'Rejection reason'),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: isAr ? 'السبب' : 'Reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isAr ? 'رفض' : 'Reject'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      reason = ctrl.text.trim();
      if (reason.isEmpty) return;
    } else {
      final amountCtrl = TextEditingController(text: '${request.amountIqd}');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isAr ? 'تأكيد الموافقة' : 'Confirm approval'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'المبلغ المطلوب من السائق: ${fare.formatIqd(request.amountIqd)}'
                    : 'Driver requested: ${fare.formatIqd(request.amountIqd)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isAr
                      ? 'المبلغ المعتمد للشحن (د.ع)'
                      : 'Amount to credit (IQD)',
                  helperText: isAr
                      ? 'يمكنك تعديل المبلغ قبل الاعتماد'
                      : 'You can edit the amount before approving',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isAr ? 'موافقة' : 'Approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      approvedAmount = int.tryParse(amountCtrl.text.trim());
      if (approvedAmount == null || approvedAmount < 1000) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? 'المبلغ المعتمد يجب أن يكون 1000 د.ع على الأقل'
                  : 'Approved amount must be at least 1000 IQD',
            ),
          ),
        );
        return;
      }
    }

    try {
      await context.read<AppState>().walletService.reviewRechargeRequest(
            requestId: request.id,
            approve: approve,
            rejectionReason: reason,
            approvedAmountIqd: approvedAmount,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? (isAr
                    ? 'تمت الموافقة وشحن ${fare.formatIqd(approvedAmount ?? request.amountIqd)}'
                    : 'Approved and credited ${fare.formatIqd(approvedAmount ?? request.amountIqd)}')
                : (isAr ? 'تم الرفض' : 'Rejected'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<AppState>().walletService;
    return StreamBuilder<List<WalletRechargeRequest>>(
      stream: wallet.watchPendingRechargeRequests(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return Center(
            child: Text(isAr ? 'لا توجد طلبات معلّقة' : 'No pending requests'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final req = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${req.driverName.isEmpty ? req.driverId : req.driverName}'
                            '${req.driverPhone.isNotEmpty ? ' • ${req.driverPhone}' : ''}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openDriverWallet(context, req),
                          child: Text(isAr ? 'المحفظة' : 'Wallet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fare.formatIqd(req.amountIqd)} • ${req.method.value}'
                      '${req.referenceNumber.isNotEmpty ? ' • ref ${req.referenceNumber}' : ''}',
                    ),
                    if (req.notes.isNotEmpty) Text(req.notes),
                    if (req.createdAt != null)
                      Text(
                        req.createdAt!.toLocal().toString().substring(0, 16),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (req.screenshotUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          req.screenshotUrl,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            isAr ? 'تعذّر تحميل الصورة' : 'Image failed to load',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _review(
                              context,
                              request: req,
                              approve: true,
                            ),
                            child: Text(isAr ? 'موافقة' : 'Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _review(
                              context,
                              request: req,
                              approve: false,
                            ),
                            child: Text(isAr ? 'رفض' : 'Reject'),
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
    );
  }
}

class _AdjustWalletTab extends StatefulWidget {
  const _AdjustWalletTab({required this.fare, required this.isAr});

  final FareService fare;
  final bool isAr;

  @override
  State<_AdjustWalletTab> createState() => _AdjustWalletTabState();
}

class _AdjustWalletTabState extends State<_AdjustWalletTab> {
  final _driverIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _driverIdCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    final driverId = _driverIdCtrl.text.trim();
    final note = _noteCtrl.text.trim();
    if (driverId.isEmpty || amount == 0 || note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'أدخل معرّف السائق والمبلغ والملاحظة'
                : 'Enter driver id, amount, and note',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().walletService.adjustWallet(
            driverId: driverId,
            amountIqd: amount,
            note: note,
          );
      if (!mounted) return;
      _amountCtrl.clear();
      _noteCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr ? 'تم تعديل الرصيد' : 'Wallet adjusted'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openWallet() {
    final driverId = _driverIdCtrl.text.trim();
    if (driverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'أدخل معرّف السائق أولاً'
                : 'Enter driver UID first',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminDriverWalletScreen(driverId: driverId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.isAr
              ? 'مبلغ موجب = إضافة، سالب = خصم'
              : 'Positive amount = credit, negative = debit',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _driverIdCtrl,
          decoration: InputDecoration(
            labelText: widget.isAr ? 'معرّف السائق (UID)' : 'Driver UID',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openWallet,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(
            widget.isAr
                ? 'فتح محفظة السائق والسجل'
                : 'Open driver wallet + ledger',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.isAr ? 'المبلغ (د.ع)' : 'Amount (IQD)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: widget.isAr ? 'ملاحظة (مطلوبة)' : 'Note (required)',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isAr ? 'تطبيق' : 'Apply'),
        ),
      ],
    );
  }
}

class _WalletSettingsTab extends StatefulWidget {
  const _WalletSettingsTab({required this.isAr});

  final bool isAr;

  @override
  State<_WalletSettingsTab> createState() => _WalletSettingsTabState();
}

class _WalletSettingsTabState extends State<_WalletSettingsTab> {
  final _numberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _lowCtrl = TextEditingController();
  final _enCtrl = TextEditingController();
  final _arCtrl = TextEditingController();
  var _loaded = false;
  var _busy = false;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _minCtrl.dispose();
    _lowCtrl.dispose();
    _enCtrl.dispose();
    _arCtrl.dispose();
    super.dispose();
  }

  void _hydrate(WalletConfig config) {
    if (_loaded) return;
    _loaded = true;
    _numberCtrl.text = config.companySuperQiNumber;
    _nameCtrl.text = config.companySuperQiName;
    _minCtrl.text = '${config.minBalanceIqd < 1 ? 1 : config.minBalanceIqd}';
    _lowCtrl.text = '${config.lowBalanceWarningIqd}';
    _enCtrl.text = config.rechargeInstructionsEn;
    _arCtrl.text = config.rechargeInstructionsAr;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final config = WalletConfig(
        minBalanceIqd: int.tryParse(_minCtrl.text.trim()) ?? 0,
        lowBalanceWarningIqd: int.tryParse(_lowCtrl.text.trim()) ?? 5000,
        companySuperQiNumber: _numberCtrl.text.trim(),
        companySuperQiName: _nameCtrl.text.trim().isEmpty
            ? 'Hello Tuk-Tuk'
            : _nameCtrl.text.trim(),
        rechargeInstructionsEn: _enCtrl.text.trim(),
        rechargeInstructionsAr: _arCtrl.text.trim(),
      );
      await context.read<AppState>().walletService.saveConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr ? 'تم حفظ الإعدادات' : 'Settings saved'),
        ),
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
    return StreamBuilder<WalletConfig>(
      stream: context.watch<AppState>().walletService.watchConfig(),
      builder: (context, snap) {
        final config = snap.data ?? const WalletConfig();
        _hydrate(config);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.isAr
                  ? 'اضبط رقم سوبر كي الحقيقي هنا بعد النشر.'
                  : 'Set the real company SuperQi number here after deploy.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: widget.isAr ? 'اسم الحساب' : 'Account name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numberCtrl,
              decoration: InputDecoration(
                labelText:
                    widget.isAr ? 'رقم سوبر كي للشركة' : 'Company SuperQi number',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.isAr
                    ? 'الحد الأدنى للمطابقة (د.ع)'
                    : 'Min balance for matching (IQD)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lowCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.isAr
                    ? 'تحذير الرصيد المنخفض (د.ع)'
                    : 'Low-balance warning (IQD)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _enCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Instructions (EN)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _arCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Instructions (AR)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isAr ? 'حفظ' : 'Save'),
            ),
          ],
        );
      },
    );
  }
}
