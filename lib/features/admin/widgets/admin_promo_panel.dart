import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/input_parsers.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminPromoPanel extends StatefulWidget {
  const AdminPromoPanel({super.key});

  @override
  State<AdminPromoPanel> createState() => _AdminPromoPanelState();
}

class _AdminPromoPanelState extends State<AdminPromoPanel> {
  final _codeController = TextEditingController(text: 'FREE3');
  final _discountController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _maxRidesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _maxRedemptionsController = TextEditingController();
  final _minRidesController = TextEditingController(text: '0');
  final _districtIdsController = TextEditingController();
  final _loyaltyRidesController = TextEditingController(text: '10');
  var _enabled = true;
  var _autoAssign = true;
  var _kind = 'both';
  DateTime? _expiresAt;
  var _isSaving = false;
  var _isLoading = true;
  var _loyaltyEnabled = false;
  var _loyaltyRepeats = true;
  var _loyaltySaving = false;
  var _loyaltyLoaded = false;
  StreamSubscription<PromoCodeConfig>? _subscription;
  StreamSubscription<LoyaltyConfig>? _loyaltySubscription;
  List<PromoCodeConfig> _allPromos = const [];

  @override
  void initState() {
    super.initState();
    _startWatching();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _loyaltySubscription?.cancel();
    _codeController.dispose();
    _discountController.dispose();
    _maxDiscountController.dispose();
    _maxRidesController.dispose();
    _descriptionController.dispose();
    _maxRedemptionsController.dispose();
    _minRidesController.dispose();
    _districtIdsController.dispose();
    _loyaltyRidesController.dispose();
    super.dispose();
  }

  void _startWatching() {
    final promoService = context.read<AppState>().promoService;
    unawaited(promoService.ensureFree3Exists());
    promoService.watchAllPromoCodes().listen((configs) {
      if (!mounted) return;
      setState(() {
        _allPromos = configs;
        _isLoading = false;
      });
    });
    _loyaltySubscription = promoService.watchLoyaltyConfig().listen((config) {
      if (!mounted || _loyaltySaving) return;
      setState(() {
        _loyaltyEnabled = config.enabled;
        _loyaltyRepeats = config.repeats;
        _loyaltyRidesController.text = '${config.ridesRequired}';
        _loyaltyLoaded = true;
      });
    });
    _watchSelectedCode();
  }

  void _watchSelectedCode() {
    _subscription?.cancel();
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    _subscription = context.read<AppState>().promoService.watchPromoCode(code).listen(
      (config) {
        if (!mounted || _isSaving) return;
        setState(() => _applyConfig(config));
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _applyConfig(PromoCodeConfig.free3Defaults));
      },
    );
  }

  void _applyConfig(PromoCodeConfig config) {
    _codeController.text = config.code;
    _enabled = config.enabled;
    _autoAssign = config.autoAssignOnSignup;
    _kind = config.kind;
    _expiresAt = config.expiresAt;
    _discountController.text = config.discountPercent.toString();
    _maxDiscountController.text = config.maxDiscountIqd.toString();
    _maxRidesController.text = config.maxRides.toString();
    _descriptionController.text = config.description;
    _maxRedemptionsController.text =
        config.maxTotalRedemptions?.toString() ?? '';
    _minRidesController.text = config.minCompletedRidesForEligibility.toString();
    _districtIdsController.text = config.districtIds.join(', ');
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final districtIds = _districtIdsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final maxRedemptions = parseIntInput(_maxRedemptionsController.text);

      final config = PromoCodeConfig(
        code: code,
        enabled: _enabled,
        autoAssignOnSignup: _autoAssign,
        discountPercent: parseIntInput(_discountController.text) ?? 50,
        maxDiscountIqd: parseIntInput(_maxDiscountController.text) ?? 1000,
        maxRides: parseIntInput(_maxRidesController.text) ?? 2,
        description: _descriptionController.text.trim(),
        expiresAt: _expiresAt,
        maxTotalRedemptions: maxRedemptions,
        currentRedemptions: _allPromos
                .where((p) => p.code == code)
                .map((p) => p.currentRedemptions)
                .firstOrNull ??
            0,
        districtIds: districtIds,
        minCompletedRidesForEligibility:
            parseIntInput(_minRidesController.text) ?? 0,
        kind: _kind,
      );
      await context.read<AppState>().promoService.savePromoCode(config);
      if (!mounted) return;
      _watchSelectedCode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.promoCodeSaved)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveLoyalty() async {
    setState(() => _loyaltySaving = true);
    try {
      final ridesRequired =
          parseIntInput(_loyaltyRidesController.text) ?? 10;
      await context.read<AppState>().promoService.saveLoyaltyConfig(
            LoyaltyConfig(
              enabled: _loyaltyEnabled,
              ridesRequired: ridesRequired < 1 ? 1 : ridesRequired,
              repeats: _loyaltyRepeats,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.localeName.startsWith('ar')
                ? 'تم حفظ إعدادات الولاء'
                : 'Loyalty settings saved',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _loyaltySaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');

    if (_isLoading && !_loyaltyLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isAr ? 'ولاء العملاء — مشوار مجاني' : 'Customer loyalty — free ride',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? 'بعد عدد محدد من الرحلات المكتملة يحصل العميل على مشوار مجاني، ويُحوَّل مبلغ الرحلة لمحفظة السائق.'
                      : 'After a set number of completed rides, the customer gets a free ride and the trip cost is credited to the driver’s wallet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isAr ? 'تفعيل الولاء' : 'Enable loyalty'),
                  value: _loyaltyEnabled,
                  onChanged: _loyaltySaving
                      ? null
                      : (value) => setState(() => _loyaltyEnabled = value),
                ),
                TextField(
                  controller: _loyaltyRidesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr
                        ? 'عدد الرحلات المطلوبة'
                        : 'Completed rides required',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isAr ? 'يتكرر كل N رحلات' : 'Repeats every N rides',
                  ),
                  subtitle: Text(
                    isAr
                        ? 'إيقافه يمنح مشواراً مجانياً مرة واحدة فقط عند الوصول للعدد'
                        : 'Off = one free ride only when the threshold is first reached',
                  ),
                  value: _loyaltyRepeats,
                  onChanged: _loyaltySaving
                      ? null
                      : (value) => setState(() => _loyaltyRepeats = value),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loyaltySaving ? null : _saveLoyalty,
                  child: _loyaltySaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isAr ? 'حفظ الولاء' : 'Save loyalty'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.promoCodesTab,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(l10n.promoCodesHint),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final promo in _allPromos)
              ChoiceChip(
                label: Text(promo.code),
                selected: _codeController.text.trim().toUpperCase() == promo.code,
                onSelected: (_) {
                  _codeController.text = promo.code;
                  _watchSelectedCode();
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: Text(isAr ? 'رمز جديد' : 'New code'),
              onPressed: () {
                _codeController.clear();
                setState(() {
                  _enabled = true;
                  _autoAssign = false;
                  _kind = 'both';
                  _expiresAt = null;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.promoCodeLabel,
                    hintText: 'SUMMER25',
                  ),
                  onSubmitted: (_) => _watchSelectedCode(),
                  onEditingComplete: _watchSelectedCode,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.promoEnabledLabel),
                  subtitle: Text(l10n.promoEnabledHint),
                  value: _enabled,
                  onChanged:
                      _isSaving ? null : (value) => setState(() => _enabled = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.promoAutoAssignLabel),
                  subtitle: Text(l10n.promoAutoAssignHint),
                  value: _autoAssign,
                  onChanged:
                      _isSaving ? null : (value) => setState(() => _autoAssign = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _kind,
                  decoration: InputDecoration(
                    labelText: isAr ? 'النوع' : 'Kind',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'ride', child: Text(isAr ? 'رحلة' : 'Ride')),
                    DropdownMenuItem(
                      value: 'delivery',
                      child: Text(isAr ? 'توصيل' : 'Delivery'),
                    ),
                    DropdownMenuItem(value: 'both', child: Text(isAr ? 'كلاهما' : 'Both')),
                  ],
                  onChanged: _isSaving ? null : (v) => setState(() => _kind = v ?? 'both'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.promoDiscountPercentLabel,
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxDiscountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.promoMaxDiscountLabel,
                    suffixText: 'IQD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxRidesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.promoMaxRidesLabel,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _maxRedemptionsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr ? 'حد الاستخدام الكلي' : 'Max total redemptions',
                    hintText: isAr ? 'فارغ = غير محدود' : 'Empty = unlimited',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minRidesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isAr ? 'حد أدنى للرحلات المكتملة' : 'Min completed rides',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _districtIdsController,
                  decoration: InputDecoration(
                    labelText: isAr ? 'مناطق (معرفات مفصولة بفاصلة)' : 'District IDs (comma-separated)',
                    hintText: isAr ? 'فارغ = كل المناطق' : 'Empty = all areas',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isAr ? 'تاريخ الانتهاء' : 'Expiry date'),
                  subtitle: Text(
                    _expiresAt == null
                        ? (isAr ? 'بدون انتهاء' : 'No expiry')
                        : _expiresAt!.toIso8601String().substring(0, 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_expiresAt != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _isSaving ? null : () => setState(() => _expiresAt = null),
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _isSaving ? null : _pickExpiry,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.promoDescriptionLabel,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.savePromoCode),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
