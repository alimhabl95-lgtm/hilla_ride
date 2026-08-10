import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/app_services.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_detail_screen.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:provider/provider.dart';

class AdminDriverPerformancePanel extends StatefulWidget {
  const AdminDriverPerformancePanel({super.key});

  @override
  State<AdminDriverPerformancePanel> createState() =>
      _AdminDriverPerformancePanelState();
}

class _AdminDriverPerformancePanelState
    extends State<AdminDriverPerformancePanel> {
  var _filters = AdminFilterCriteria.empty;
  var _sortByTripsDesc = true;
  static const _fare = FareService();

  bool _matchesDriverStatus(DriverProfile d) {
    final status = _filters.driverStatus;
    if (status == null) return true;
    return switch (status) {
      'online' => d.isOnline && !d.isBlocked,
      'offline' => !d.isOnline,
      'approved' => d.approvalStatus == DriverApprovalStatus.approved,
      'pending' => d.approvalStatus == DriverApprovalStatus.pending,
      'blocked' => d.isBlocked,
      'busy' => d.hasActiveRide,
      _ => true,
    };
  }

  bool _matches(DriverProfile d) {
    final catalog = ServiceAreaCatalog.instance;
    final provinceId = catalog.provinceIdForDistrict(d.assignedDistrictId);
    if (!_filters.matchesGeo(
      provinceId: provinceId,
      districtId: d.assignedDistrictId,
      subDistrictId: d.assignedSubDistrictId,
    )) {
      return false;
    }
    if (!_matchesDriverStatus(d)) return false;
    final q = _filters.query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = '${d.name} ${d.phone} ${d.uid}'.toLowerCase();
    return haystack.contains(q);
  }

  double _acceptanceRate(DriverProfile d) {
    if (d.statsOffersReceived <= 0) return 0;
    return d.statsOffersAccepted / d.statsOffersReceived;
  }

  double _cancellationRate(DriverProfile d) {
    final total = d.completedRidesCount + d.cancelledRidesCount;
    if (total <= 0) return 0;
    return d.cancelledRidesCount / total;
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final locale = isAr ? 'ar' : 'en';
    final catalog = ServiceAreaCatalog.instance;
    final adminService = context.read<AppState>().adminService;
    final driverService = context.read<AppState>().driverService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminFilterBar(
          value: _filters,
          onChanged: (v) => setState(() => _filters = v),
          fields: const [
            AdminFilterField.province,
            AdminFilterField.district,
            AdminFilterField.subDistrict,
            AdminFilterField.driverStatus,
            AdminFilterField.search,
          ],
          hintText: isAr ? 'بحث سائق' : 'Search driver',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(isAr ? 'ترتيب:' : 'Sort:'),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(isAr ? 'الرحلات المكتملة' : 'Completed trips'),
                selected: _sortByTripsDesc,
                onSelected: (v) => setState(() => _sortByTripsDesc = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<DriverProfile>>(
            stream: adminService.watchAllDrivers(),
            builder: (context, snapshot) {
              final drivers = List<DriverProfile>.from(snapshot.data ?? const [])
                ..retainWhere(_matches)
                ..sort((a, b) => _sortByTripsDesc
                    ? b.completedRidesCount.compareTo(a.completedRidesCount)
                    : a.completedRidesCount.compareTo(b.completedRidesCount));

              if (drivers.isEmpty) {
                return Center(
                  child: Text(isAr ? 'لا يوجد سائقون' : 'No drivers'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: drivers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final d = drivers[index];
                  final acceptPct = (_acceptanceRate(d) * 100).toStringAsFixed(1);
                  final cancelPct =
                      (_cancellationRate(d) * 100).toStringAsFixed(1);
                  final onlineHours =
                      (d.onlineSecondsTotal / 3600).toStringAsFixed(1);
                  final geo = [
                    if (d.assignedDistrictId.isNotEmpty)
                      catalog.localizedDistrictName(
                        d.assignedDistrictId,
                        isAr: isAr,
                      ),
                    if (d.assignedSubDistrictId.isNotEmpty)
                      catalog.localizedSubName(
                        d.assignedSubDistrictId,
                        isAr: isAr,
                      ),
                  ].join(' • ');

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('${d.phone}${geo.isEmpty ? '' : ' • $geo'}'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _MetricChip(
                                label: isAr ? 'قبول' : 'Accept',
                                value: '$acceptPct%',
                              ),
                              _MetricChip(
                                label: isAr ? 'إلغاء' : 'Cancel',
                                value: '$cancelPct%',
                              ),
                              _MetricChip(
                                label: isAr ? 'التقييم' : 'Rating',
                                value: d.rating.toStringAsFixed(1),
                              ),
                              _MetricChip(
                                label: isAr ? 'مكتملة' : 'Completed',
                                value: '${d.completedRidesCount}',
                              ),
                              _MetricChip(
                                label: isAr ? 'متصل' : 'Online h',
                                value: onlineHours,
                              ),
                              _MetricChip(
                                label: isAr ? 'المحفظة' : 'Wallet',
                                value: _fare.formatIqd(
                                  d.walletBalanceIqd,
                                  locale: locale,
                                ),
                              ),
                              _MetricChip(
                                label: isAr ? 'مكافآت' : 'Rewards',
                                value: _fare.formatIqd(
                                  d.totalRewardsEarnedIqd,
                                  locale: locale,
                                ),
                              ),
                              if (d.warningCount > 0)
                                _MetricChip(
                                  label: isAr ? 'تحذيرات' : 'Warnings',
                                  value: '${d.warningCount}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(isAr ? 'التفاصيل' : 'Details'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          AdminDriverDetailScreen(driver: d),
                                    ),
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.warning_amber_outlined, size: 18),
                                label: Text(isAr ? 'تحذير' : 'Send Warning'),
                                onPressed: () => _warnDriver(context, d.uid, isAr),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.pause_circle_outline, size: 18),
                                label: Text(isAr ? 'تعليق' : 'Suspend'),
                                onPressed: () => _suspendDriver(
                                  context,
                                  driverService: driverService,
                                  driver: d,
                                  isAr: isAr,
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
          ),
        ),
      ],
    );
  }

  Future<void> _warnDriver(
    BuildContext context,
    String driverId,
    bool isAr,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'إرسال تحذير؟' : 'Send warning?'),
        content: Text(
          isAr
              ? 'سيتم إرسال إشعار للسائق وتسجيل التحذير.'
              : 'The driver will receive a push notification and the warning will be logged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'إرسال' : 'Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('warnDriver')
          .call({'driverId': driverId});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم إرسال التحذير' : 'Warning sent')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _suspendDriver(
    BuildContext context, {
    required DriverService driverService,
    required DriverProfile driver,
    required bool isAr,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تعليق السائق؟' : 'Suspend driver?'),
        content: Text(
          isAr
              ? 'سيتم حظر السائق من العمل حتى إعادة تفعيله.'
              : 'The driver will be blocked from going online until re-enabled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'تعليق' : 'Suspend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await driverService.setDriverBlocked(driverId: driver.uid, blocked: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isAr ? 'تم تعليق السائق' : 'Driver suspended')),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      label: Text(label),
    );
  }
}
