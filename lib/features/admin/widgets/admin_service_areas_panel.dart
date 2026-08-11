import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/service_area_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/features/admin/screens/admin_area_boundary_editor_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class AdminServiceAreasPanel extends StatefulWidget {
  const AdminServiceAreasPanel({super.key});

  @override
  State<AdminServiceAreasPanel> createState() => _AdminServiceAreasPanelState();
}

class _AdminServiceAreasPanelState extends State<AdminServiceAreasPanel> {
  String? _countryId;
  String? _provinceId;
  String? _districtId;
  var _seeding = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final areas = context.watch<AppState>().serviceAreaService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isAr ? 'إدارة مناطق الخدمة' : 'Service area management',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              FilledButton.icon(
                onPressed: _seeding
                    ? null
                    : () async {
                        setState(() => _seeding = true);
                        try {
                          await areas.seedDefaults();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isAr
                                    ? 'تم نشر مناطق بابل الافتراضية'
                                    : 'Seeded default Babil service areas',
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        } finally {
                          if (mounted) setState(() => _seeding = false);
                        }
                      },
                icon: _seeding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(isAr ? 'نشر مناطق بابل' : 'Seed Babil defaults'),
              ),
              Text(
                isAr
                    ? 'التسلسل: محافظة → قضاء → ناحية. الإيقاف/الأرشفة يوقف الطلبات الجديدة فوراً مع حفظ السجل. التعديلات تصل لتطبيقات السائق والزبون بدون تحديث المتجر.'
                    : 'Hierarchy: Province → District → Subdistrict. Deactivate/archive blocks new rides immediately while keeping history. Changes sync to driver/customer apps with no store update.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _LevelColumn(
                  title: isAr ? 'الدول' : 'Countries',
                  child: StreamBuilder<List<ServiceCountry>>(
                    stream: areas.watchCountries(),
                    builder: (context, snap) {
                      final items = snap.data ?? const [];
                      return _EntityList(
                        emptyLabel: isAr ? 'لا دول — انشر البذرة' : 'No countries — seed first',
                        items: items
                            .map(
                              (c) => _EntityRow(
                                id: c.id,
                                title: isAr ? c.nameAr : c.nameEn,
                                subtitle:
                                    '${c.code} • ${_statusLabel(c.status, isAr)}',
                                selected: _countryId == c.id,
                                isAr: isAr,
                                onTap: () => setState(() {
                                  _countryId = c.id;
                                  _provinceId = null;
                                  _districtId = null;
                                }),
                                onEdit: () => _editCountry(context, c, isAr),
                                onToggle: () => areas.setAreaStatus(
                                  kind: 'country',
                                  id: c.id,
                                  status: c.isActive
                                      ? ServiceAreaStatus.inactive
                                      : ServiceAreaStatus.active,
                                ),
                                onArchive: () => areas.archiveArea(
                                  kind: 'country',
                                  id: c.id,
                                ),
                                onDelete: () => areas.deleteArea(
                                  kind: 'country',
                                  id: c.id,
                                ),
                              ),
                            )
                            .toList(),
                        onAdd: () => _editCountry(context, null, isAr),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: _LevelColumn(
                  title: isAr ? 'المحافظات' : 'Provinces',
                  child: StreamBuilder<List<ServiceProvince>>(
                    stream: areas.watchProvinces(countryId: _countryId),
                    builder: (context, snap) {
                      final items = snap.data ?? const [];
                      return _EntityList(
                        emptyLabel: isAr ? 'اختر دولة' : 'Select a country',
                        items: items
                            .map(
                              (p) => _EntityRow(
                                id: p.id,
                                title: isAr ? p.nameAr : p.nameEn,
                                subtitle:
                                    '${_statusLabel(p.status, isAr)}${p.customerVisible ? (isAr ? ' • زبائن' : ' • customer') : ''}',
                                selected: _provinceId == p.id,
                                isAr: isAr,
                                onTap: () => setState(() {
                                  _provinceId = p.id;
                                  _districtId = null;
                                }),
                                onEdit: () => _editProvince(context, p, isAr),
                                onToggle: () => areas.setAreaStatus(
                                  kind: 'province',
                                  id: p.id,
                                  status: p.isActive
                                      ? ServiceAreaStatus.inactive
                                      : ServiceAreaStatus.active,
                                ),
                                onArchive: () => areas.archiveArea(
                                  kind: 'province',
                                  id: p.id,
                                ),
                                onDelete: () => areas.deleteArea(
                                  kind: 'province',
                                  id: p.id,
                                ),
                              ),
                            )
                            .toList(),
                        onAdd: _countryId == null
                            ? null
                            : () => _editProvince(context, null, isAr),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                child: _LevelColumn(
                  title: isAr ? 'الأقضية' : 'Districts',
                  child: StreamBuilder<List<ServiceDistrict>>(
                    stream: areas.watchDistricts(provinceId: _provinceId),
                    builder: (context, snap) {
                      final items = snap.data ?? const [];
                      return _EntityList(
                        emptyLabel: isAr ? 'اختر محافظة' : 'Select a province',
                        items: items
                            .map(
                              (d) => _EntityRow(
                                id: d.id,
                                title: isAr ? d.nameAr : d.nameEn,
                                subtitle:
                                    '${_statusLabel(d.status, isAr)}${d.customerVisible ? (isAr ? ' • زبائن' : ' • customer') : ''}',
                                selected: _districtId == d.id,
                                isAr: isAr,
                                onTap: () => setState(() => _districtId = d.id),
                                onEdit: () => _editDistrict(context, d, isAr),
                                onToggle: () => areas.setAreaStatus(
                                  kind: 'district',
                                  id: d.id,
                                  status: d.isActive
                                      ? ServiceAreaStatus.inactive
                                      : ServiceAreaStatus.active,
                                ),
                                onArchive: () => areas.archiveArea(
                                  kind: 'district',
                                  id: d.id,
                                ),
                                onDelete: () => areas.deleteArea(
                                  kind: 'district',
                                  id: d.id,
                                ),
                              ),
                            )
                            .toList(),
                        onAdd: _provinceId == null || _countryId == null
                            ? null
                            : () => _editDistrict(context, null, isAr),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _LevelColumn(
                  title: isAr ? 'النواحي / مناطق الخدمة' : 'Sub-districts',
                  child: StreamBuilder<List<ServiceSubDistrict>>(
                    stream: areas.watchSubDistricts(districtId: _districtId),
                    builder: (context, snap) {
                      final items = snap.data ?? const [];
                      return _EntityList(
                        emptyLabel:
                            isAr ? 'اختر قضاء' : 'Select a district',
                        items: items
                            .map(
                              (s) => _EntityRow(
                                id: s.id,
                                title: isAr ? s.nameAr : s.nameEn,
                                subtitle:
                                    '${_statusLabel(s.status, isAr)} • r=${s.searchRadiusKm}km • '
                                    '${(s.boundary?.length ?? 0) >= 3 ? (isAr ? "حدود مرسومة" : "drawn boundary") : (isAr ? "دائرة مؤقتة" : "temp circle")} • '
                                    '${s.services.join(",")}',
                                selected: false,
                                isAr: isAr,
                                onTap: () => _editSubDistrict(context, s, isAr),
                                onEdit: () => _editSubDistrict(context, s, isAr),
                                onEditBoundary: () => _editBoundary(context, s, isAr),
                                onToggle: () => areas.setAreaStatus(
                                  kind: 'subDistrict',
                                  id: s.id,
                                  status: s.isActive
                                      ? ServiceAreaStatus.inactive
                                      : ServiceAreaStatus.active,
                                ),
                                onArchive: () => areas.archiveArea(
                                  kind: 'subDistrict',
                                  id: s.id,
                                ),
                                onDelete: () => areas.deleteArea(
                                  kind: 'subDistrict',
                                  id: s.id,
                                ),
                              ),
                            )
                            .toList(),
                        onAdd: _districtId == null ||
                                _provinceId == null ||
                                _countryId == null
                            ? null
                            : () => _editSubDistrict(context, null, isAr),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editCountry(
    BuildContext context,
    ServiceCountry? existing,
    bool isAr,
  ) async {
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final enCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? 'IQ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'دولة' : 'Country'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idCtrl,
                enabled: existing == null,
                decoration: const InputDecoration(labelText: 'ID (iq)'),
              ),
              TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'Name EN')),
              TextField(controller: arCtrl, decoration: const InputDecoration(labelText: 'Name AR')),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Code')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().serviceAreaService.saveCountry(
          ServiceCountry(
            id: idCtrl.text.trim(),
            nameEn: enCtrl.text.trim(),
            nameAr: arCtrl.text.trim(),
            code: codeCtrl.text.trim(),
            status: existing?.status ?? ServiceAreaStatus.active,
          ),
        );
  }

  Future<void> _editProvince(
    BuildContext context,
    ServiceProvince? existing,
    bool isAr,
  ) async {
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final enCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    var customerVisible = existing?.customerVisible ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isAr ? 'محافظة' : 'Province'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  enabled: existing == null,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'Name EN')),
                TextField(controller: arCtrl, decoration: const InputDecoration(labelText: 'Name AR')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isAr ? 'ظاهر للزبائن' : 'Visible to customers'),
                  subtitle: Text(
                    isAr
                        ? 'أوقف هذا لتحضير محافظة جديدة في الأدمن قبل إظهارها للزبائن'
                        : 'Turn off to stage a new governorate in Admin before it appears to customers',
                  ),
                  value: customerVisible,
                  onChanged: (v) => setLocal(() => customerVisible = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().serviceAreaService.saveProvince(
          ServiceProvince(
            id: idCtrl.text.trim(),
            countryId: existing?.countryId ?? _countryId!,
            nameEn: enCtrl.text.trim(),
            nameAr: arCtrl.text.trim(),
            customerVisible: customerVisible,
            status: existing?.status ?? ServiceAreaStatus.active,
          ),
        );
  }

  Future<void> _editDistrict(
    BuildContext context,
    ServiceDistrict? existing,
    bool isAr,
  ) async {
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final enCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    var customerVisible = existing?.customerVisible ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isAr ? 'قضاء' : 'District'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  enabled: existing == null,
                  decoration: const InputDecoration(labelText: 'ID'),
                ),
                TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'Name EN')),
                TextField(controller: arCtrl, decoration: const InputDecoration(labelText: 'Name AR')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(isAr ? 'ظاهر للزبائن' : 'Visible to customers'),
                  value: customerVisible,
                  onChanged: (v) => setLocal(() => customerVisible = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().serviceAreaService.saveDistrict(
          ServiceDistrict(
            id: idCtrl.text.trim(),
            provinceId: existing?.provinceId ?? _provinceId!,
            countryId: existing?.countryId ?? _countryId!,
            nameEn: enCtrl.text.trim(),
            nameAr: arCtrl.text.trim(),
            customerVisible: customerVisible,
            status: existing?.status ?? ServiceAreaStatus.active,
          ),
        );
  }

  Future<void> _editBoundary(
    BuildContext context,
    ServiceSubDistrict subDistrict,
    bool isAr,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminAreaBoundaryEditorScreen(
          subDistrict: subDistrict,
          isAr: isAr,
        ),
      ),
    );
  }

  Future<void> _editSubDistrict(
    BuildContext context,
    ServiceSubDistrict? existing,
    bool isAr,
  ) async {
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final enCtrl = TextEditingController(text: existing?.nameEn ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    final latCtrl = TextEditingController(
      text: existing != null ? '${existing.center.latitude}' : '',
    );
    final lngCtrl = TextEditingController(
      text: existing != null ? '${existing.center.longitude}' : '',
    );
    final radiusCtrl = TextEditingController(
      text: '${existing?.searchRadiusKm ?? 22}',
    );
    final commissionCtrl = TextEditingController(
      text: existing?.commissionPercent?.toString() ?? '',
    );
    final baseFareCtrl = TextEditingController(
      text: existing?.pricing.baseFareIqd?.toString() ?? '',
    );
    final perKmCtrl = TextEditingController(
      text: existing?.pricing.perKmIqd?.toString() ?? '',
    );
    final minFareCtrl = TextEditingController(
      text: existing?.pricing.minimumFareIqd?.toString() ?? '',
    );
    final services = {...(existing?.services ?? [ServiceTypeIds.ride])};
    var useGlobalCommission = existing?.useGlobalCommission ?? true;
    var useGlobalPricing = existing?.pricing.useGlobalPricing ?? true;
    var alwaysOpen = existing?.operatingHours.alwaysOpen ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isAr ? 'ناحية / منطقة خدمة' : 'Sub-district / service area'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idCtrl,
                    enabled: existing == null,
                    decoration: const InputDecoration(labelText: 'ID'),
                  ),
                  TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'Name EN')),
                  TextField(controller: arCtrl, decoration: const InputDecoration(labelText: 'Name AR')),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          decoration: const InputDecoration(labelText: 'Latitude'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lngCtrl,
                          decoration: const InputDecoration(labelText: 'Longitude'),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: radiusCtrl,
                    decoration: InputDecoration(
                      labelText: isAr ? 'نصف قطر البحث (كم)' : 'Search radius (km)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(isAr ? 'الخدمات' : 'Services'),
                  ),
                  Wrap(
                    children: [
                      for (final s in ServiceTypeIds.all)
                        FilterChip(
                          label: Text(s),
                          selected: services.contains(s),
                          onSelected: (v) => setLocal(() {
                            if (v) {
                              services.add(s);
                            } else {
                              services.remove(s);
                            }
                          }),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAr ? 'عمولة عامة' : 'Use global commission'),
                    value: useGlobalCommission,
                    onChanged: (v) => setLocal(() => useGlobalCommission = v),
                  ),
                  if (!useGlobalCommission)
                    TextField(
                      controller: commissionCtrl,
                      decoration: InputDecoration(
                        labelText: isAr ? 'نسبة العمولة %' : 'Commission %',
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAr ? 'تسعير عام' : 'Use global pricing'),
                    value: useGlobalPricing,
                    onChanged: (v) => setLocal(() => useGlobalPricing = v),
                  ),
                  if (!useGlobalPricing) ...[
                    TextField(
                      controller: baseFareCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'الأجرة الأساسية (د.ع)' : 'Base fare (IQD)',
                      ),
                    ),
                    TextField(
                      controller: perKmCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'لكل كم (د.ع)' : 'Per km (IQD)',
                      ),
                    ),
                    TextField(
                      controller: minFareCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isAr ? 'الحد الأدنى (د.ع)' : 'Minimum fare (IQD)',
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAr ? 'مفتوح دائماً' : 'Always open'),
                    subtitle: Text(
                      isAr
                          ? 'عند الإيقاف تُرفض الطلبات الجديدة خارج الجدول'
                          : 'When off, new requests are rejected outside the schedule',
                    ),
                    value: alwaysOpen,
                    onChanged: (v) => setLocal(() => alwaysOpen = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final lat = double.tryParse(latCtrl.text.trim()) ?? 0;
    final lng = double.tryParse(lngCtrl.text.trim()) ?? 0;
    await context.read<AppState>().serviceAreaService.saveSubDistrict(
          ServiceSubDistrict(
            id: idCtrl.text.trim(),
            districtId: existing?.districtId ?? _districtId!,
            provinceId: existing?.provinceId ?? _provinceId!,
            countryId: existing?.countryId ?? _countryId!,
            nameEn: enCtrl.text.trim(),
            nameAr: arCtrl.text.trim(),
            center: LatLng(lat, lng),
            searchRadiusKm: double.tryParse(radiusCtrl.text.trim()) ?? 22,
            // Preserve any Admin-drawn polygon — this dialog never edits it.
            boundary: existing?.boundary,
            status: existing?.status ?? ServiceAreaStatus.active,
            services: services.isEmpty ? [ServiceTypeIds.ride] : services.toList(),
            useGlobalCommission: useGlobalCommission,
            commissionPercent: double.tryParse(commissionCtrl.text.trim()),
            pricing: AreaPricingRules(
              useGlobalPricing: useGlobalPricing,
              baseFareIqd: int.tryParse(baseFareCtrl.text.trim()),
              perKmIqd: int.tryParse(perKmCtrl.text.trim()),
              minimumFareIqd: int.tryParse(minFareCtrl.text.trim()),
            ),
            operatingHours: OperatingHours(alwaysOpen: alwaysOpen),
          ),
        );
  }
}

String _statusLabel(ServiceAreaStatus status, bool isAr) {
  return switch (status) {
    ServiceAreaStatus.active => isAr ? 'نشط' : 'active',
    ServiceAreaStatus.inactive => isAr ? 'متوقف' : 'inactive',
    ServiceAreaStatus.maintenance => isAr ? 'صيانة' : 'maintenance',
    ServiceAreaStatus.archived => isAr ? 'مؤرشف' : 'archived',
  };
}

class _LevelColumn extends StatelessWidget {
  const _LevelColumn({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _EntityRow {
  const _EntityRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onArchive,
    required this.onDelete,
    this.onEditBoundary,
    this.isAr = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool selected;
  final bool isAr;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onToggle;
  final Future<void> Function() onArchive;
  final Future<void> Function() onDelete;

  /// Only set for sub-district rows — opens the polygon boundary editor.
  final VoidCallback? onEditBoundary;
}

class _EntityList extends StatelessWidget {
  const _EntityList({
    required this.items,
    required this.emptyLabel,
    required this.onAdd,
  });

  final List<_EntityRow> items;
  final String emptyLabel;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onAdd != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(emptyLabel))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      selected: item.selected,
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      onTap: item.onTap,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') item.onEdit();
                          if (v == 'editBoundary') item.onEditBoundary?.call();
                          if (v == 'toggle') await item.onToggle();
                          if (v == 'archive') await item.onArchive();
                          if (v == 'delete') await item.onDelete();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(item.isAr ? 'تعديل' : 'Edit'),
                          ),
                          if (item.onEditBoundary != null)
                            PopupMenuItem(
                              value: 'editBoundary',
                              child: Text(
                                item.isAr ? 'تعديل الحدود' : 'Edit boundary',
                              ),
                            ),
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              item.isAr
                                  ? 'تفعيل / إيقاف'
                                  : 'Activate / deactivate',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Text(item.isAr ? 'أرشفة' : 'Archive'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(item.isAr ? 'حذف' : 'Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
