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
  static const _code = 'FREE3';

  final _discountController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _maxRidesController = TextEditingController();
  final _descriptionController = TextEditingController();
  var _enabled = true;
  var _autoAssign = true;
  var _isSaving = false;
  var _isLoading = true;
  StreamSubscription<PromoCodeConfig>? _subscription;

  @override
  void initState() {
    super.initState();
    _startWatching();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _discountController.dispose();
    _maxDiscountController.dispose();
    _maxRidesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startWatching() {
    _subscription?.cancel();
    final promoService = context.read<AppState>().promoService;
    unawaited(promoService.ensureFree3Exists());
    _subscription = promoService.watchPromoCode(_code).listen(
      (config) {
        if (!mounted || _isSaving) return;
        setState(() {
          _applyConfig(config);
          _isLoading = false;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _applyConfig(PromoCodeConfig.free3Defaults);
          _isLoading = false;
        });
      },
    );
  }

  void _applyConfig(PromoCodeConfig config) {
    _enabled = config.enabled;
    _autoAssign = config.autoAssignOnSignup;
    _discountController.text = config.discountPercent.toString();
    _maxDiscountController.text = config.maxDiscountIqd.toString();
    _maxRidesController.text = config.maxRides.toString();
    _descriptionController.text = config.description;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final config = PromoCodeConfig(
        code: _code,
        enabled: _enabled,
        autoAssignOnSignup: _autoAssign,
        discountPercent: parseIntInput(_discountController.text) ?? 50,
        maxDiscountIqd: parseIntInput(_maxDiscountController.text) ?? 1000,
        maxRides: parseIntInput(_maxRidesController.text) ?? 2,
        description: _descriptionController.text.trim(),
      );
      await context.read<AppState>().promoService.savePromoCode(config);
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.promoCodesTab,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(l10n.promoCodesHint),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.promoCodeLabel),
                  subtitle: Text(_code),
                  trailing: Chip(
                    label: Text(l10n.promoCodeActive),
                    backgroundColor: _enabled
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.promoEnabledLabel),
                  subtitle: Text(l10n.promoEnabledHint),
                  value: _enabled,
                  onChanged: _isSaving ? null : (value) => setState(() => _enabled = value),
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
