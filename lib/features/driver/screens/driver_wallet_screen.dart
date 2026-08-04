import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key, required this.driver});

  final DriverProfile driver;

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  static const _fare = FareService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
    final wallet = context.watch<AppState>().walletService;
    final driverService = context.watch<AppState>().driverService;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'المحفظة' : 'Wallet'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: isAr ? 'الرصيد' : 'Balance'),
            Tab(text: isAr ? 'السجل' : 'History'),
          ],
        ),
      ),
      body: StreamBuilder<DriverProfile?>(
        stream: driverService.watchDriver(widget.driver.uid),
        builder: (context, driverSnap) {
          final driver = driverSnap.data ?? widget.driver;
          return StreamBuilder<WalletConfig>(
            stream: wallet.watchConfig(),
            builder: (context, configSnap) {
              final config = configSnap.data ?? const WalletConfig();
              final low = driver.walletBalanceIqd <= config.lowBalanceWarningIqd;
              final blocked = driver.walletStatus == 'blocked' ||
                  driver.walletBalanceIqd < config.minBalanceIqd;

              return TabBarView(
                controller: _tabs,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr ? 'الرصيد الحالي' : 'Current balance',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fare.formatIqd(
                                  driver.walletBalanceIqd,
                                  locale: l10n.localeName,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: const Color(0xFF0F766E),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                blocked
                                    ? (isAr
                                        ? 'الحالة: محظور — اشحن المحفظة لاستقبال الرحلات'
                                        : 'Status: Blocked — recharge to receive trips')
                                    : low
                                        ? (isAr
                                            ? 'الحالة: رصيد منخفض'
                                            : 'Status: Low balance')
                                        : (isAr
                                            ? 'الحالة: نشط'
                                            : 'Status: Active'),
                                style: TextStyle(
                                  color: blocked
                                      ? Colors.red
                                      : low
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF0F766E),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (low || blocked) ...[
                        const SizedBox(height: 12),
                        MaterialBanner(
                          content: Text(
                            isAr
                                ? 'رصيد المحفظة منخفض. اشحن عبر سوبر كي لمتابعة استقبال الرحلات.'
                                : 'Wallet balance is low. Recharge via SuperQi to keep receiving trips.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {},
                              child: const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DriverWalletRechargeScreen(
                                driver: driver,
                                config: config,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_card),
                        label: Text(isAr ? 'شحن المحفظة' : 'Recharge wallet'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAr
                            ? 'هذه محفظة داخلية لعمولة الشركة فقط وليست محفظة سوبر كي.'
                            : 'This is an internal Hello Tuk-Tuk wallet for company commission only — not a SuperQi wallet.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  StreamBuilder<List<WalletLedgerEntry>>(
                    stream: wallet.watchLedger(driver.uid),
                    builder: (context, snap) {
                      final entries = snap.data ?? const [];
                      if (entries.isEmpty) {
                        return Center(
                          child: Text(isAr ? 'لا توجد عمليات بعد' : 'No ledger entries yet'),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final credit = e.amountIqd >= 0;
                          return ListTile(
                            leading: Icon(
                              credit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: credit ? Colors.green : Colors.red,
                            ),
                            title: Text(_ledgerTypeLabel(e.type, isAr)),
                            subtitle: Text(
                              [
                                if (e.note.isNotEmpty) e.note,
                                if (e.createdAt != null)
                                  e.createdAt!.toLocal().toString().substring(0, 16),
                              ].where((s) => s.isNotEmpty).join('\n'),
                            ),
                            trailing: Text(
                              '${credit ? '+' : ''}${_fare.formatIqd(e.amountIqd, locale: l10n.localeName)}',
                              style: TextStyle(
                                color: credit ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _ledgerTypeLabel(WalletLedgerType type, bool isAr) {
  return switch (type) {
    WalletLedgerType.recharge => isAr ? 'شحن' : 'Recharge',
    WalletLedgerType.commission => isAr ? 'عمولة' : 'Commission',
    WalletLedgerType.adjustment => isAr ? 'تعديل' : 'Adjustment',
    WalletLedgerType.refund => isAr ? 'استرداد' : 'Refund',
    WalletLedgerType.bonus => isAr ? 'مكافأة' : 'Bonus',
    WalletLedgerType.penalty => isAr ? 'غرامة' : 'Penalty',
    WalletLedgerType.reward => isAr ? 'حافز / مكافأة' : 'Reward',
  };
}

class DriverWalletRechargeScreen extends StatefulWidget {
  const DriverWalletRechargeScreen({
    super.key,
    required this.driver,
    required this.config,
  });

  final DriverProfile driver;
  final WalletConfig config;

  @override
  State<DriverWalletRechargeScreen> createState() =>
      _DriverWalletRechargeScreenState();
}

class _DriverWalletRechargeScreenState extends State<DriverWalletRechargeScreen> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Uint8List? _screenshotBytes;
  var _submitting = false;
  WalletRechargeMethod _method = WalletRechargeMethod.superQi;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _screenshotBytes = bytes);
  }

  Future<void> _sendReceiptWhatsApp() async {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final digits = widget.config.managerWhatsappDigits;
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'لم يُضبط رقم واتساب الإدارة بعد'
                : 'Manager WhatsApp number is not set yet',
          ),
        ),
      );
      return;
    }
    final amount = _amountCtrl.text.trim();
    final ref = _refCtrl.text.trim();
    final driver = widget.driver;
    final message = isAr
        ? 'شحن محفظة Hello Tuk-Tuk\n'
            'السائق: ${driver.name}\n'
            'الهاتف: ${driver.phone}\n'
            'المبلغ: ${amount.isEmpty ? '—' : amount} د.ع\n'
            'الطريقة: ${_method.value}\n'
            'المرجع: ${ref.isEmpty ? '—' : ref}\n'
            'أرفق صورة إيصال الدفع في هذه المحادثة.'
        : 'Hello Tuk-Tuk wallet recharge\n'
            'Driver: ${driver.name}\n'
            'Phone: ${driver.phone}\n'
            'Amount: ${amount.isEmpty ? '—' : amount} IQD\n'
            'Method: ${_method.value}\n'
            'Ref: ${ref.isEmpty ? '—' : ref}\n'
            'Please attach the payment receipt screenshot here.';
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تعذر فتح واتساب' : 'Could not open WhatsApp',
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'الحد الأدنى 1000 د.ع' : 'Minimum is 1000 IQD'),
        ),
      );
      return;
    }
    if (_screenshotBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'أرفق صورة إيصال الدفع' : 'Attach a payment screenshot',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final wallet = context.read<AppState>().walletService;
      final url = await wallet.uploadRechargeScreenshot(
        driverId: widget.driver.uid,
        bytes: _screenshotBytes!,
      );
      await wallet.submitRechargeRequest(
        amountIqd: amount,
        method: _method,
        screenshotUrl: url,
        referenceNumber: _refCtrl.text,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تم إرسال الطلب — بانتظار التحقق'
                : 'Request submitted — pending verification',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final config = widget.config;

    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'شحن عبر سوبر كي' : 'SuperQi recharge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.companySuperQiName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    config.companySuperQiNumber.isEmpty
                        ? (isAr
                            ? 'لم يُضبط رقم سوبر كي بعد — تواصل مع الإدارة'
                            : 'SuperQi number not set yet — contact admin')
                        : config.companySuperQiNumber,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: const Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(config.instructionsForLocale(l10n.localeName)),
                  if (config.managerWhatsappDigits.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'واتساب استلام الإيصال' : 'Send receipt on WhatsApp',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      config.managerWhatsappNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _sendReceiptWhatsApp,
                      icon: const Icon(Icons.chat),
                      label: Text(
                        isAr
                            ? 'فتح واتساب وإرسال الإيصال'
                            : 'Open WhatsApp & send receipt',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'أرفق صورة الإيصال داخل واتساب بعد فتح المحادثة.'
                          : 'Attach the receipt photo inside WhatsApp after the chat opens.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<WalletRechargeMethod>(
            // ignore: deprecated_member_use
            value: _method,
            decoration: InputDecoration(
              labelText: isAr ? 'طريقة الدفع' : 'Payment method',
            ),
            items: [
              for (final m in [
                WalletRechargeMethod.superQi,
                WalletRechargeMethod.cash,
                WalletRechargeMethod.bankTransfer,
              ])
                if (config.enabledMethods.contains(m.value))
                  DropdownMenuItem(value: m, child: Text(m.value)),
            ],
            onChanged: (v) => setState(() => _method = v ?? _method),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: isAr ? 'المبلغ (د.ع)' : 'Amount (IQD)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refCtrl,
            decoration: InputDecoration(
              labelText: isAr
                  ? 'رقم المرجع (اختياري)'
                  : 'Reference number (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: isAr ? 'ملاحظات (اختياري)' : 'Notes (optional)',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickScreenshot,
            icon: const Icon(Icons.image),
            label: Text(
              _screenshotBytes == null
                  ? (isAr ? 'إرفاق صورة الإيصال' : 'Attach receipt screenshot')
                  : (isAr ? 'تم اختيار الصورة' : 'Screenshot selected'),
            ),
          ),
          if (_screenshotBytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_screenshotBytes!, height: 180, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isAr
                        ? 'أتممت الدفع — إرسال للمراجعة'
                        : 'I completed payment — submit',
                  ),
          ),
        ],
      ),
    );
  }
}
