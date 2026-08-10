import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminDriverDistrictPanel extends StatefulWidget {
  const AdminDriverDistrictPanel({
    super.key,
    required this.driver,
  });

  final DriverProfile driver;

  @override
  State<AdminDriverDistrictPanel> createState() =>
      _AdminDriverDistrictPanelState();
}

class _AdminDriverDistrictPanelState extends State<AdminDriverDistrictPanel> {
  late String _districtId;
  late String _subDistrictId;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncFromDriver();
  }

  void _syncFromDriver() {
    final catalog = ServiceAreaCatalog.instance;
    final districts = catalog.districtsForAdminFilters;
    _districtId = widget.driver.assignedDistrictId.isNotEmpty
        ? widget.driver.assignedDistrictId
        : (districts.isNotEmpty
            ? districts.first.id
            : BabilRegions.customerDistrictId);
    final district = BabilRegions.districtById(_districtId);
    final subs = catalog.subsForDistrict(_districtId);
    if (widget.driver.assignedSubDistrictId.isNotEmpty) {
      _subDistrictId = widget.driver.assignedSubDistrictId;
    } else if (subs.isNotEmpty) {
      _subDistrictId = subs.first.id;
    } else {
      _subDistrictId = district.subDistricts.first.id;
    }
  }

  @override
  void didUpdateWidget(covariant AdminDriverDistrictPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver.uid != widget.driver.uid) {
      _syncFromDriver();
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      await context.read<AppState>().adminService.setDriverWorkDistrict(
            driverId: widget.driver.uid,
            districtId: _districtId,
            subDistrictId: _subDistrictId,
          );
      if (widget.driver.isOnline && mounted) {
        await context
            .read<AppState>()
            .driverService
            .refreshOnlineMatchingProfile(widget.driver.uid);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.driverWorkDistrictSaved)),
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
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';

    return ListenableBuilder(
      listenable: ServiceAreaCatalog.instance,
      builder: (context, _) {
        final catalog = ServiceAreaCatalog.instance;
        final districts = catalog.districtsForAdminFilters;
        final districtIds = districts.map((d) => d.id).toSet();
        final safeDistrictId =
            districtIds.contains(_districtId) ? _districtId : null;
        final subs = catalog.subsForDistrict(safeDistrictId ?? _districtId);
        final subIds = subs.map((s) => s.id).toSet();
        final safeSubId =
            subIds.contains(_subDistrictId) ? _subDistrictId : null;

        return Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.driverWorkDistrictLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.driverWorkDistrictHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (!widget.driver.hasAssignedWorkArea) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.driverWorkDistrictRequired,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: safeDistrictId,
                  decoration: InputDecoration(
                    labelText: l10n.districtLabel,
                    isDense: true,
                  ),
                  items: districts
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(isArabic ? d.nameAr : d.nameEn),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          final nextSubs = catalog.subsForDistrict(value);
                          setState(() {
                            _districtId = value;
                            _subDistrictId = nextSubs.isNotEmpty
                                ? nextSubs.first.id
                                : BabilRegions.districtById(value)
                                    .subDistricts
                                    .first
                                    .id;
                          });
                        },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: safeSubId,
                  decoration: InputDecoration(
                    labelText: l10n.subDistrictLabel,
                    isDense: true,
                  ),
                  items: subs
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(isArabic ? s.nameAr : s.nameEn),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _subDistrictId = value);
                        },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.saveDriverWorkDistrict),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
