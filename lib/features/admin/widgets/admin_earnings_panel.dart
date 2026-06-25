import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/commission_config.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_detail_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminEarningsPanel extends StatefulWidget {
  const AdminEarningsPanel({super.key});

  @override
  State<AdminEarningsPanel> createState() => _AdminEarningsPanelState();
}

class _AdminEarningsPanelState extends State<AdminEarningsPanel> {
  final _percentController = TextEditingController();
  var _isSaving = false;
  var _loaded = false;
  var _reconciled = false;
  final _receivingDriverIds = <String>{};
  String? _cityFilterId;

  String _districtLabel(BabilDistrict district, String localeName) {
    return localeName.startsWith('ar') ? district.nameAr : district.nameEn;
  }

  String _driverCityLabel(DriverProfile driver, String localeName) {
    if (!driver.hasAssignedWorkArea) return '—';
    final district = BabilRegions.districtById(driver.assignedDistrictId);
    final sub = BabilRegions.subDistrictById(
      driver.assignedDistrictId,
      driver.assignedSubDistrictId,
    );
    final districtName =
        localeName.startsWith('ar') ? district.nameAr : district.nameEn;
    final subName = localeName.startsWith('ar') ? sub.nameAr : sub.nameEn;
    return '$districtName • $subName';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcilePendingEarnings());
  }

  @override
  void dispose() {
    _percentController.dispose();
    super.dispose();
  }

  void _loadConfig(CommissionConfig config) {
    if (_loaded) return;
    _loaded = true;
    _percentController.text = config.platformPercent.toStringAsFixed(1);
  }

  Future<void> _reconcilePendingEarnings() async {
    if (_reconciled || !mounted) return;
    _reconciled = true;
    try {
      await context.read<AppState>().rideService.applyPendingEarnings();
    } catch (_) {
      // Best-effort backfill; dashboard still shows live driver totals.
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final percent = double.tryParse(_percentController.text.trim());
      if (percent == null || percent < 0 || percent > 100) {
        throw StateError('invalid_percent');
      }

      await context.read<AppState>().commissionService.saveConfig(
            CommissionConfig(platformPercent: percent),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commissionSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.commissionSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _markProfitsReceived(
    DriverProfile driver,
    FareService fareService,
    AppLocalizations l10n,
  ) async {
    if (driver.owedPlatformCommissionIqd <= 0) return;

    final auth = context.read<AppState>().authService.currentUser;
    if (auth == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.receivedProfitsTitle),
        content: Text(
          l10n.receivedProfitsConfirm(
            fareService.formatIqd(
              driver.owedPlatformCommissionIqd,
              locale: l10n.localeName,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.receivedProfitsAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _receivingDriverIds.add(driver.uid));
    try {
      await context.read<AppState>().adminService.markProfitsReceived(
            driverId: driver.uid,
            receivedByUid: auth.uid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.receivedProfitsSuccess)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _receivingDriverIds.remove(driver.uid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final commissionService = context.read<AppState>().commissionService;
    final adminService = context.read<AppState>().adminService;

    return StreamBuilder<CommissionConfig>(
      stream: commissionService.watchConfig(),
      builder: (context, configSnapshot) {
        final config = configSnapshot.data ?? CommissionConfig.defaults;
        _loadConfig(config);

        return StreamBuilder<List<DriverProfile>>(
          stream: adminService.watchAllDrivers(),
          builder: (context, driversSnapshot) {
            final allDrivers = driversSnapshot.data ?? const [];
            final drivers = _cityFilterId == null
                ? allDrivers
                : allDrivers
                    .where(
                      (driver) =>
                          driver.assignedDistrictId == _cityFilterId,
                    )
                    .toList();
            final totalOutstanding = drivers.fold<int>(
              0,
              (sum, driver) => sum + driver.owedPlatformCommissionIqd,
            );
            final totalLifetime = drivers.fold<int>(
              0,
              (sum, driver) => sum + driver.totalPlatformCommissionIqd,
            );
            final groupedDrivers = <String, List<DriverProfile>>{};
            for (final driver in drivers) {
              final key = driver.assignedDistrictId.isEmpty
                  ? '_unassigned'
                  : driver.assignedDistrictId;
              groupedDrivers.putIfAbsent(key, () => []).add(driver);
            }
            final groupKeys = groupedDrivers.keys.toList()
              ..sort((a, b) {
                if (a == '_unassigned') return 1;
                if (b == '_unassigned') return -1;
                final districtA = BabilRegions.districtById(a);
                final districtB = BabilRegions.districtById(b);
                return districtA.nameEn.compareTo(districtB.nameEn);
              });

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  l10n.commissionSettingsTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(l10n.commissionSettingsHint),
                const SizedBox(height: 16),
                TextField(
                  controller: _percentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.platformPercentLabel,
                    suffixText: '%',
                  ),
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
                      : const Icon(Icons.save),
                  label: Text(l10n.saveCommissionSettings),
                ),
                const SizedBox(height: 32),
                DropdownButtonFormField<String?>(
                  value: _cityFilterId,
                  decoration: InputDecoration(
                    labelText: l10n.filterByCity,
                    prefixIcon: const Icon(Icons.location_city_outlined),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.allCities),
                    ),
                    for (final district in BabilRegions.districts)
                      DropdownMenuItem<String?>(
                        value: district.id,
                        child: Text(
                          _districtLabel(district, l10n.localeName),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _cityFilterId = value),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: ListTile(
                    title: Text(l10n.outstandingProfitTotal),
                    subtitle: Text(
                      fareService.formatIqd(
                        totalOutstanding,
                        locale: l10n.localeName,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: Text(l10n.lifetimeProfitTotal),
                    subtitle: Text(
                      fareService.formatIqd(
                        totalLifetime,
                        locale: l10n.localeName,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.managerProfitByDriver,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${l10n.platformPercentLabel}: ${config.platformPercent.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (drivers.isEmpty)
                  Text(l10n.noPendingDrivers)
                else
                  for (final groupKey in groupKeys) ...[
                    Builder(
                      builder: (context) {
                        final groupDrivers = groupedDrivers[groupKey]!
                          ..sort(
                            (a, b) => a.name
                                .toLowerCase()
                                .compareTo(b.name.toLowerCase()),
                          );
                        final groupOutstanding = groupDrivers.fold<int>(
                          0,
                          (sum, driver) =>
                              sum + driver.owedPlatformCommissionIqd,
                        );
                        final groupTitle = groupKey == '_unassigned'
                            ? l10n.driverWorkDistrictRequired
                            : _districtLabel(
                                BabilRegions.districtById(groupKey),
                                l10n.localeName,
                              );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 8),
                              child: ListTile(
                                tileColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                title: Text(groupTitle),
                                subtitle: Text(
                                  '${l10n.outstandingProfitTotal}: ${fareService.formatIqd(groupOutstanding, locale: l10n.localeName)}',
                                ),
                              ),
                            ),
                            ...groupDrivers.map((driver) {
                              final isReceiving =
                                  _receivingDriverIds.contains(driver.uid);
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          driver.name.isEmpty
                                              ? '—'
                                              : driver.name,
                                        ),
                                        subtitle: Text(
                                          '${l10n.driverWorkDistrictLabel}: ${_driverCityLabel(driver, l10n.localeName)}\n'
                                          '${l10n.completedRidesCount}: ${driver.completedRidesCount}\n'
                                          '${l10n.outstandingProfitLabel}: ${fareService.formatIqd(driver.owedPlatformCommissionIqd, locale: l10n.localeName)}\n'
                                          '${l10n.lifetimeProfitLabel}: ${fareService.formatIqd(driver.totalPlatformCommissionIqd, locale: l10n.localeName)}\n'
                                          '${l10n.driverNetEarnings}: ${fareService.formatIqd(driver.totalDriverEarningsIqd, locale: l10n.localeName)}',
                                        ),
                                        isThreeLine: true,
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AdminDriverDetailScreen(
                                              driver: driver,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (driver.owedPlatformCommissionIqd > 0)
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: FilledButton.tonalIcon(
                                            onPressed: isReceiving
                                                ? null
                                                : () => _markProfitsReceived(
                                                      driver,
                                                      fareService,
                                                      l10n,
                                                    ),
                                            icon: isReceiving
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.check_circle_outline,
                                                  ),
                                            label: Text(
                                              l10n.receivedProfitsAction,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ],
              ],
            );
          },
        );
      },
    );
  }
}
