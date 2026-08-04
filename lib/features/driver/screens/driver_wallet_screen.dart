import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
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

  String _statusSubtitle({
    required bool blocked,
    required bool low,
    required bool isAr,
  }) {
    if (blocked) {
      return isAr
          ? 'الحالة: محظور — اشحن المحفظة لاستقبال الرحلات'
          : 'Status: Blocked — recharge to receive trips';
    }
    if (low) {
      return isAr ? 'الحالة: رصيد منخفض' : 'Status: Low balance';
    }
    return isAr ? 'الحالة: نشط' : 'Status: Active';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final wallet = context.watch<AppState>().walletService;
    final driverService = context.watch<AppState>().driverService;

    return Scaffold(
      backgroundColor: AppBrandAssets.brandSurface,
      appBar: AppBar(
        title: Text(isAr ? 'المحفظة' : 'Wallet'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
              final low =
                  driver.walletBalanceIqd <= config.lowBalanceWarningIqd;
              final blocked = driver.walletStatus == 'blocked' ||
                  driver.walletBalanceIqd < config.minBalanceIqd;

              return TabBarView(
                controller: _tabs,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      AppWalletCard(
                        title: isAr ? 'الرصيد الحالي' : 'Current balance',
                        balanceLabel: _fare.formatIqd(
                          driver.walletBalanceIqd,
                          locale: l10n.localeName,
                        ),
                        subtitle: _statusSubtitle(
                          blocked: blocked,
                          low: low,
                          isAr: isAr,
                        ),
                      ),
                      if (low || blocked) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppBanner(
                          message: isAr
                              ? 'رصيد المحفظة منخفض. اشحن عبر سوبر كي لمتابعة استقبال الرحلات.'
                              : 'Wallet balance is low. Recharge via SuperQi to keep receiving trips.',
                          icon: Icons.warning_amber_rounded,
                          tone: blocked
                              ? AppBannerTone.danger
                              : AppBannerTone.warning,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        label: isAr ? 'شحن المحفظة' : 'Recharge wallet',
                        icon: Icons.add_card,
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
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isAr
                            ? 'هذه محفظة داخلية لعمولة الشركة فقط وليست محفظة سوبر كي.'
                            : 'This is an internal Hello Tuk-Tuk wallet for company commission only — not a SuperQi wallet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppBrandAssets.brandMuted,
                            ),
                      ),
                    ],
                  ),
                  StreamBuilder<List<WalletLedgerEntry>>(
                    stream: wallet.watchLedger(driver.uid),
                    builder: (context, snap) {
                      final entries = snap.data ?? const [];
                      if (entries.isEmpty) {
                        return AppEmptyState(
                          title: isAr
                              ? 'لا توجد عمليات بعد'
                              : 'No ledger entries yet',
                          message: isAr
                              ? 'ستظهر عمليات الشحن والعمولة هنا'
                              : 'Recharges and commissions will appear here',
                          icon: Icons.receipt_long_outlined,
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: entries.length,
                        separatorBuilder: (_, _index) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final e = entries[index];
                          final credit = e.amountIqd >= 0;
                          return AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (credit
                                            ? AppBrandAssets.brandSuccess
                                            : AppBrandAssets.brandDanger)
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child: Icon(
                                    credit
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: credit
                                        ? AppBrandAssets.brandSuccess
                                        : AppBrandAssets.brandDanger,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _ledgerTypeLabel(e.type, isAr),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppBrandAssets.brandNavy,
                                            ),
                                      ),
                                      if (e.note.isNotEmpty ||
                                          e.createdAt != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (e.note.isNotEmpty) e.note,
                                            if (e.createdAt != null)
                                              e.createdAt!
                                                  .toLocal()
                                                  .toString()
                                                  .substring(0, 16),
                                          ].join('\n'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppBrandAssets.brandMuted,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '${credit ? '+' : ''}${_fare.formatIqd(e.amountIqd, locale: l10n.localeName)}',
                                  style: TextStyle(
                                    color: credit
                                        ? AppBrandAssets.brandSuccess
                                        : AppBrandAssets.brandDanger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
      backgroundColor: AppBrandAssets.brandSurface,
      appBar: AppBar(title: Text(isAr ? 'شحن عبر سوبر كي' : 'SuperQi recharge')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.companySuperQiName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppBrandAssets.brandNavy,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  config.companySuperQiNumber.isEmpty
                      ? (isAr
                          ? 'لم يُضبط رقم سوبر كي بعد — تواصل مع الإدارة'
                          : 'SuperQi number not set yet — contact admin')
                      : config.companySuperQiNumber,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppBrandAssets.brandTealDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  config.instructionsForLocale(l10n.localeName),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppBrandAssets.brandMuted,
                      ),
                ),
                if (config.managerWhatsappDigits.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    isAr ? 'واتساب استلام الإيصال' : 'Send receipt on WhatsApp',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppBrandAssets.brandNavy,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    config.managerWhatsappNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppBrandAssets.brandTealDark,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppPrimaryButton(
                    label: isAr
                        ? 'فتح واتساب وإرسال الإيصال'
                        : 'Open WhatsApp & send receipt',
                    icon: Icons.chat,
                    onPressed: _sendReceiptWhatsApp,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isAr
                        ? 'أرفق صورة الإيصال داخل واتساب بعد فتح المحادثة.'
                        : 'Attach the receipt photo inside WhatsApp after the chat opens.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppBrandAssets.brandMuted,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<WalletRechargeMethod>(
                  // ignore: deprecated_member_use
                  value: _method,
                  decoration: InputDecoration(
                    labelText: isAr ? 'طريقة الدفع' : 'Payment method',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
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
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr ? 'المبلغ (د.ع)' : 'Amount (IQD)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'رقم المرجع (اختياري)'
                        : 'Reference number (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        isAr ? 'ملاحظات (اختياري)' : 'Notes (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  label: _screenshotBytes == null
                      ? (isAr
                          ? 'إرفاق صورة الإيصال'
                          : 'Attach receipt screenshot')
                      : (isAr ? 'تم اختيار الصورة' : 'Screenshot selected'),
                  icon: Icons.image_outlined,
                  onPressed: _submitting ? null : _pickScreenshot,
                ),
                if (_screenshotBytes != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: Image.memory(
                      _screenshotBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: isAr
                ? 'أتممت الدفع — إرسال للمراجعة'
                : 'I completed payment — submit',
            icon: Icons.send_rounded,
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
