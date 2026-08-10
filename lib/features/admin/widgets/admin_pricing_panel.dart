import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/pricing_config.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/core/utils/input_parsers.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminPricingPanel extends StatefulWidget {
  const AdminPricingPanel({super.key});

  @override
  State<AdminPricingPanel> createState() => _AdminPricingPanelState();
}

class _AdminPricingPanelState extends State<AdminPricingPanel> {
  final _maxDistanceController = TextEditingController();
  final List<_BracketFields> _brackets = [];
  var _isSaving = false;
  var _isLoading = true;
  var _showLoadWarning = false;
  String? _appliedFingerprint;
  late String _selectedDistrictId;
  String? _selectedSubDistrictId;
  StreamSubscription<PricingConfig>? _pricingSubscription;

  @override
  void initState() {
    super.initState();
    final districts = ServiceAreaCatalog.instance.districtsForAdminFilters;
    _selectedDistrictId =
        districts.isNotEmpty ? districts.first.id : BabilRegions.customerDistrict.id;
    _applyConfig(PricingConfig.defaults);
    _startWatchingPricing();
  }

  @override
  void dispose() {
    _pricingSubscription?.cancel();
    _maxDistanceController.dispose();
    for (final bracket in _brackets) {
      bracket.dispose();
    }
    super.dispose();
  }

  void _startWatchingPricing() {
    _pricingSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _showLoadWarning = false;
    });

    final pricingService = context.read<AppState>().pricingService;
    _pricingSubscription = pricingService
        .watchConfig(
          districtId: _selectedDistrictId,
          subDistrictId: _selectedSubDistrictId,
        )
        .listen(
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
          _applyConfig(PricingConfig.defaults);
          _showLoadWarning = true;
          _isLoading = false;
        });
      },
    );
  }

  void _applyConfig(PricingConfig config) {
    if (_isSaving) return;
    if (_appliedFingerprint == config.fingerprint) return;

    _appliedFingerprint = config.fingerprint;
    _maxDistanceController.text = config.maxDistanceKm.toStringAsFixed(2);
    for (final bracket in _brackets) {
      bracket.dispose();
    }
    _brackets
      ..clear()
      ..addAll(
        config.brackets.map(
          (b) => _BracketFields(
            minKm: b.minKm,
            maxKm: b.maxKm,
            priceIqd: b.priceIqd,
          ),
        ),
      );
  }

  void _onDistrictChanged(String? value) {
    if (value == null || value == _selectedDistrictId || _isSaving) return;
    setState(() {
      _selectedDistrictId = value;
      _selectedSubDistrictId = null;
      _appliedFingerprint = null;
    });
    _startWatchingPricing();
  }

  void _onSubDistrictChanged(String? value) {
    if (_isSaving || value == _selectedSubDistrictId) return;
    setState(() {
      _selectedSubDistrictId = value;
      _appliedFingerprint = null;
    });
    _startWatchingPricing();
  }

  void _addBracket() {
    setState(() {
      final lastMax = _brackets.isEmpty
          ? 0.0
          : (parseDecimalInput(_brackets.last.maxController.text) ?? 0);
      _brackets.add(
        _BracketFields(
          minKm: lastMax > 0 ? lastMax + 0.01 : 0,
          maxKm: lastMax > 0 ? lastMax + 1.25 : 1.25,
          priceIqd: 1000,
        ),
      );
    });
  }

  void _removeBracket(int index) {
    if (_brackets.length <= 1) return;
    setState(() {
      _brackets[index].dispose();
      _brackets.removeAt(index);
    });
  }

  PricingConfig? _readForm() {
    final maxDistanceKm = parseDecimalInput(_maxDistanceController.text);
    if (maxDistanceKm == null || maxDistanceKm <= 0) {
      return null;
    }
    if (_brackets.isEmpty) {
      return null;
    }

    final brackets = <PricingBracket>[];
    for (final field in _brackets) {
      final minKm = parseDecimalInput(field.minController.text);
      final maxKm = parseDecimalInput(field.maxController.text);
      final priceIqd = parseIntInput(field.priceController.text);
      if (minKm == null || maxKm == null || priceIqd == null || priceIqd < 0) {
        return null;
      }
      brackets.add(
        PricingBracket(minKm: minKm, maxKm: maxKm, priceIqd: priceIqd),
      );
    }

    return PricingConfig(maxDistanceKm: maxDistanceKm, brackets: brackets);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final config = _readForm();
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pricingInvalidValues)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<AppState>().pricingService.saveConfig(
            districtId: _selectedDistrictId,
            subDistrictId: _selectedSubDistrictId,
            config: config,
          );

      if (!mounted) return;
      setState(() {
        _applyConfig(config);
        _showLoadWarning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pricingSaved)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pricingSaveErrorMessage(
              genericMessage: l10n.pricingSaveFailed,
              permissionMessage: l10n.pricingSavePermissionDenied,
              error: error,
            ),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _areaTitle(AppLocalizations l10n, bool isArabic) {
    final catalog = ServiceAreaCatalog.instance;
    final districtLabel = catalog.localizedDistrictName(
      _selectedDistrictId,
      isAr: isArabic,
    );

    if (_selectedSubDistrictId == null) {
      return l10n.pricingForCity(districtLabel);
    }

    final subLabel = catalog.localizedSubName(
      _selectedSubDistrictId!,
      isAr: isArabic,
    );
    return l10n.pricingForArea(districtLabel, subLabel);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName.startsWith('ar');
    final canSave = _brackets.isNotEmpty && !_isSaving && !_isLoading;

    return ListenableBuilder(
      listenable: ServiceAreaCatalog.instance,
      builder: (context, _) {
        final catalog = ServiceAreaCatalog.instance;
        final districts = catalog.districtsForAdminFilters;
        final districtIds = districts.map((d) => d.id).toSet();
        final safeDistrictId = districtIds.contains(_selectedDistrictId)
            ? _selectedDistrictId
            : (districts.isNotEmpty ? districts.first.id : null);
        final districtSubs = safeDistrictId == null
            ? const <BabilSubDistrict>[]
            : catalog
                .subsForDistrict(safeDistrictId)
                .map(
                  (s) => BabilSubDistrict(
                    id: s.id,
                    nameAr: s.nameAr,
                    nameEn: s.nameEn,
                    center: s.center,
                    searchRadiusKm: s.searchRadiusKm,
                  ),
                )
                .toList();
        final subIds = districtSubs.map((s) => s.id).toSet();
        final safeSubId = _selectedSubDistrictId == null ||
                subIds.contains(_selectedSubDistrictId)
            ? _selectedSubDistrictId
            : null;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.paddingOf(context).bottom + 48,
          ),
          children: [
            Text(
              l10n.pricingRulesTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.pricingRulesHint),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: safeDistrictId,
              decoration: InputDecoration(labelText: l10n.cityPricingLabel),
              items: districts
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(isArabic ? item.nameAr : item.nameEn),
                    ),
                  )
                  .toList(),
              onChanged: _isSaving ? null : _onDistrictChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: safeSubId,
              decoration: InputDecoration(labelText: l10n.subDistrictLabel),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.pricingDistrictDefault),
                ),
                ...districtSubs.map(
                  (sub) => DropdownMenuItem<String?>(
                    value: sub.id,
                    child: Text(isArabic ? sub.nameAr : sub.nameEn),
                  ),
                ),
              ],
              onChanged: _isSaving ? null : _onSubDistrictChanged,
            ),
            if (_showLoadWarning) ...[
              const SizedBox(height: 12),
              MaterialBanner(
                content: Text(l10n.pricingUsingDefaultsHint),
                leading: const Icon(Icons.info_outline),
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                actions: const [SizedBox.shrink()],
              ),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const SizedBox(height: 24),
              Text(
                _areaTitle(l10n, isArabic),
                style: Theme.of(context).textTheme.titleMedium,
              ),
          if (_selectedSubDistrictId != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.pricingSubDistrictFallbackHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _maxDistanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.maxDistanceKmLabel,
              suffixText: 'km',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.priceBracketsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : _addBracket,
              icon: const Icon(Icons.add),
              label: Text(l10n.addBracket),
            ),
          ),
          const SizedBox(height: 12),
          ..._brackets.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final field = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: field.minController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.fromKm,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: field.maxController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: l10n.toKm,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: field.priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.priceIqd,
                                ),
                              ),
                            ),
                            if (_brackets.length > 1)
                              IconButton(
                                tooltip: l10n.removeBracket,
                                onPressed: _isSaving
                                    ? null
                                    : () => _removeBracket(index),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canSave ? _save : null,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(l10n.savePricingRules),
          ),
        ],
      ],
    );
      },
    );
  }
}

class _BracketFields {
  _BracketFields({
    required double minKm,
    required double maxKm,
    required int priceIqd,
  })  : minController = TextEditingController(text: minKm.toStringAsFixed(2)),
        maxController = TextEditingController(text: maxKm.toStringAsFixed(2)),
        priceController = TextEditingController(text: '$priceIqd');

  final TextEditingController minController;
  final TextEditingController maxController;
  final TextEditingController priceController;

  void dispose() {
    minController.dispose();
    maxController.dispose();
    priceController.dispose();
  }
}
