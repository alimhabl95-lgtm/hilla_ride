import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_wallet_screen.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:hilla_ride/features/admin/widgets/admin_wallet_withdrawals_tab.dart';
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
    _tabs = TabController(length: 4, vsync: this);
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
            Tab(text: isAr ? 'السحب' : 'Withdrawals'),
            Tab(text: isAr ? 'تعديل رصيد' : 'Adjust'),
            Tab(text: isAr ? 'الإعدادات' : 'Settings'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PendingRechargesTab(fare: _fare, isAr: isAr),
              AdminWalletWithdrawalsTab(fare: _fare, isAr: isAr),
              _AdjustWalletTab(fare: _fare, isAr: isAr),
              _WalletSettingsTab(isAr: isAr),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingRechargesTab extends StatefulWidget {
  const _PendingRechargesTab({required this.fare, required this.isAr});

  final FareService fare;
  final bool isAr;

  @override
  State<_PendingRechargesTab> createState() => _PendingRechargesTabState();
}

class _PendingRechargesTabState extends State<_PendingRechargesTab> {
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

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

  String _districtIdFor(
    WalletRechargeRequest req,
    Map<String, DriverProfile> driversById,
  ) {
    if (req.districtId.isNotEmpty) return req.districtId;
    return driversById[req.driverId]?.assignedDistrictId ?? '';
  }

  String _cityLabel(String districtId) {
    if (districtId.isEmpty) {
      return widget.isAr ? 'بدون مدينة' : 'No city';
    }
    return ServiceAreaCatalog.instance.localizedDistrictName(
      districtId,
      isAr: widget.isAr,
    );
  }

  Future<void> _review(
    BuildContext context, {
    required WalletRechargeRequest request,
    required bool approve,
  }) async {
    final isAr = widget.isAr;
    final fare = widget.fare;
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
    final isAr = widget.isAr;
    final fare = widget.fare;
    final wallet = context.watch<AppState>().walletService;
    final admin = context.watch<AppState>().adminService;

    return StreamBuilder<List<DriverProfile>>(
      stream: admin.watchAllDrivers(),
      builder: (context, driversSnap) {
        final driversById = {
          for (final d in driversSnap.data ?? const <DriverProfile>[]) d.uid: d,
        };

        return StreamBuilder<List<WalletRechargeRequest>>(
          stream: wallet.watchPendingRechargeRequests(),
          builder: (context, snap) {
            final all = snap.data ?? const [];
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = all.where((req) {
              final district = _districtIdFor(req, driversById);
              final sub = driversById[req.driverId]?.assignedSubDistrictId ?? '';
              if (!_filters.matchesGeo(
                provinceId:
                    ServiceAreaCatalog.instance.provinceIdForDistrict(district),
                districtId: district,
                subDistrictId: sub,
              )) {
                return false;
              }
              final q = _filters.query.trim().toLowerCase();
              if (q.isNotEmpty) {
                final haystack =
                    '${req.driverName} ${req.driverPhone} ${req.driverId} ${req.referenceNumber}'
                        .toLowerCase();
                if (!haystack.contains(q)) return false;
              }
              return _filters.matchesDate(req.createdAt);
            }).toList();

            return Column(
              children: [
                AdminFilterBar(
                  value: _filters,
                  onChanged: (v) => setState(() => _filters = v),
                  fields: const [
                    AdminFilterField.province,
                    AdminFilterField.district,
                    AdminFilterField.subDistrict,
                    AdminFilterField.dateRange,
                    AdminFilterField.search,
                  ],
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            isAr
                                ? 'لا توجد طلبات معلّقة'
                                : 'No pending requests',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final req = items[index];
                            final city =
                                _cityLabel(_districtIdFor(req, driversById));
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
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _openDriverWallet(context, req),
                                          child: Text(
                                            isAr ? 'المحفظة' : 'Wallet',
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      city,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF0F766E),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${fare.formatIqd(req.amountIqd)} • ${req.method.value}'
                                      '${req.referenceNumber.isNotEmpty ? ' • ref ${req.referenceNumber}' : ''}',
                                    ),
                                    if (req.notes.isNotEmpty) Text(req.notes),
                                    if (req.createdAt != null)
                                      Text(
                                        req.createdAt!
                                            .toLocal()
                                            .toString()
                                            .substring(0, 16),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    if (req.screenshotUrl.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _WalletReceiptImage(
                                        driverId: req.driverId,
                                        url: req.screenshotUrl,
                                        isAr: isAr,
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
                                            child: Text(
                                              isAr ? 'موافقة' : 'Approve',
                                            ),
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
                                            child: Text(
                                              isAr ? 'رفض' : 'Reject',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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

class _WalletReceiptImage extends StatefulWidget {
  const _WalletReceiptImage({
    required this.driverId,
    required this.url,
    required this.isAr,
  });

  final String driverId;
  final String url;
  final bool isAr;

  @override
  State<_WalletReceiptImage> createState() => _WalletReceiptImageState();
}

class _WalletReceiptImageState extends State<_WalletReceiptImage> {
  Future<Uint8List?>? _bytesFuture;
  String? _loadedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedUrl == widget.url && _bytesFuture != null) return;
    _loadedUrl = widget.url;
    _bytesFuture = context
        .read<AppState>()
        .storageService
        .loadWalletReceiptForAdmin(
          driverId: widget.driverId,
          screenshotUrl: widget.url,
        );
  }

  @override
  void didUpdateWidget(covariant _WalletReceiptImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadedUrl = widget.url;
      _bytesFuture = context
          .read<AppState>()
          .storageService
          .loadWalletReceiptForAdmin(
            driverId: widget.driverId,
            screenshotUrl: widget.url,
          );
    }
  }

  void _retry() {
    setState(() {
      _bytesFuture = context
          .read<AppState>()
          .storageService
          .loadWalletReceiptForAdmin(
            driverId: widget.driverId,
            screenshotUrl: widget.url,
          );
    });
  }

  void _preview(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(ctx).width * 0.9,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: Column(
            children: [
              AppBar(
                title: Text(widget.isAr ? 'إيصال الدفع' : 'Payment receipt'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) {
          return SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isAr ? 'تعذّر تحميل الصورة' : 'Image failed to load',
                  ),
                ),
                IconButton(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  tooltip: widget.isAr ? 'إعادة' : 'Retry',
                ),
              ],
            ),
          );
        }
        return InkWell(
          onTap: () => _preview(bytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
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
  final _whatsappCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _lowCtrl = TextEditingController();
  final _minWithdrawCtrl = TextEditingController();
  final _maxWithdrawCtrl = TextEditingController();
  final _registrationBonusCtrl = TextEditingController();
  final _enCtrl = TextEditingController();
  final _arCtrl = TextEditingController();
  var _loaded = false;
  var _busy = false;
  var _backfilling = false;
  var _withdrawalsEnabled = true;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    _minCtrl.dispose();
    _lowCtrl.dispose();
    _minWithdrawCtrl.dispose();
    _maxWithdrawCtrl.dispose();
    _registrationBonusCtrl.dispose();
    _enCtrl.dispose();
    _arCtrl.dispose();
    super.dispose();
  }

  void _hydrate(WalletConfig config) {
    if (_loaded) return;
    _loaded = true;
    _numberCtrl.text = config.companySuperQiNumber;
    _nameCtrl.text = config.companySuperQiName;
    _whatsappCtrl.text = config.managerWhatsappNumber;
    _minCtrl.text = '${config.minBalanceIqd < 1 ? 1 : config.minBalanceIqd}';
    _lowCtrl.text = '${config.lowBalanceWarningIqd}';
    _minWithdrawCtrl.text = '${config.minWithdrawalIqd}';
    _maxWithdrawCtrl.text =
        config.maxWithdrawalIqd > 0 ? '${config.maxWithdrawalIqd}' : '';
    _registrationBonusCtrl.text = '${config.registrationBonusIqd}';
    _withdrawalsEnabled = config.withdrawalsEnabled;
    _enCtrl.text = config.rechargeInstructionsEn;
    _arCtrl.text = config.rechargeInstructionsAr;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final config = WalletConfig(
        minBalanceIqd: int.tryParse(_minCtrl.text.trim()) ?? 0,
        lowBalanceWarningIqd: int.tryParse(_lowCtrl.text.trim()) ?? 5000,
        minWithdrawalIqd: int.tryParse(_minWithdrawCtrl.text.trim()) ?? 5000,
        maxWithdrawalIqd: int.tryParse(_maxWithdrawCtrl.text.trim()) ?? 0,
        withdrawalsEnabled: _withdrawalsEnabled,
        registrationBonusIqd:
            int.tryParse(_registrationBonusCtrl.text.trim()) ?? 0,
        companySuperQiNumber: _numberCtrl.text.trim(),
        companySuperQiName: _nameCtrl.text.trim().isEmpty
            ? 'Hello Tuk-Tuk'
            : _nameCtrl.text.trim(),
        managerWhatsappNumber: _whatsappCtrl.text.trim(),
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

  Future<void> _ensureWallets() async {
    setState(() => _backfilling = true);
    try {
      final result =
          await context.read<AppState>().walletService.ensureDriverWallets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'تم تهيئة المحفظة لـ ${result.updated} من ${result.total} سائق'
                : 'Initialized wallets for ${result.updated} of ${result.total} drivers',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _backfilling = false);
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
              controller: _whatsappCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: widget.isAr
                    ? 'واتساب استلام الإيصالات (للسائق)'
                    : 'WhatsApp for receipts (shown to drivers)',
                hintText: '+9647XXXXXXXXX',
                helperText: widget.isAr
                    ? 'يظهر للسائق ليرسل إيصال الشحن على واتساب'
                    : 'Drivers open this number to send SuperQi/payment receipts',
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
              controller: _registrationBonusCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.isAr
                    ? 'مكافأة تسجيل السائق (د.ع)'
                    : 'Driver registration bonus (IQD)',
                helperText: widget.isAr
                    ? 'يُضاف تلقائياً للمحفظة عند الموافقة. 0 = معطّل'
                    : 'Auto-credited to wallet on approve. 0 = disabled',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                widget.isAr ? 'تفعيل السحب للسائقين' : 'Enable driver withdrawals',
              ),
              value: _withdrawalsEnabled,
              onChanged: (v) => setState(() => _withdrawalsEnabled = v),
            ),
            TextField(
              controller: _minWithdrawCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.isAr
                    ? 'الحد الأدنى للسحب (د.ع)'
                    : 'Min withdrawal (IQD)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxWithdrawCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.isAr
                    ? 'الحد الأقصى للسحب (د.ع، فارغ = بلا حد)'
                    : 'Max withdrawal (IQD, empty = no max)',
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _backfilling ? null : _ensureWallets,
              icon: _backfilling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_wallet_outlined),
              label: Text(
                widget.isAr
                    ? 'تهيئة المحفظة لكل السائقين الحاليين'
                    : 'Initialize wallets for existing drivers',
              ),
            ),
          ],
        );
      },
    );
  }
}
