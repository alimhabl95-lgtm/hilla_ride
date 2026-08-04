import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/admin_stats_service.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminOverviewPanel extends StatefulWidget {
  const AdminOverviewPanel({super.key});

  @override
  State<AdminOverviewPanel> createState() => _AdminOverviewPanelState();
}

class _AdminOverviewPanelState extends State<AdminOverviewPanel> {
  static const _fare = FareService();

  List<Ride> _active = const [];
  List<Ride> _ridesMonth = const [];
  List<Ride> _completedMonth = const [];
  List<Ride> _cancelledMonth = const [];
  List<DriverProfile> _drivers = const [];
  List<AppUser> _customers = const [];
  List<WalletRechargeRequest> _pendingRecharges = const [];
  List<Announcement> _announcements = const [];
  final _subs = <StreamSubscription>[];
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  void _bind() {
    final admin = context.read<AppState>().adminService;
    final wallet = context.read<AppState>().walletService;
    final monthStart = AdminOverviewStats.startOfLocalDay()
        .subtract(const Duration(days: 29));

    _subs.addAll([
      admin.watchActiveRides().listen((v) => _set(() => _active = v)),
      admin.watchRidesSince(monthStart).listen((v) => _set(() => _ridesMonth = v)),
      admin
          .watchCompletedRidesSince(monthStart)
          .listen((v) => _set(() => _completedMonth = v)),
      admin
          .watchCancelledRidesSince(monthStart)
          .listen((v) => _set(() => _cancelledMonth = v)),
      admin.watchAllDrivers().listen((v) => _set(() => _drivers = v)),
      admin.watchCustomers().listen((v) => _set(() => _customers = v)),
      wallet
          .watchPendingRechargeRequests()
          .listen((v) => _set(() => _pendingRecharges = v)),
      admin
          .watchRecentAnnouncements()
          .listen((v) => _set(() => _announcements = v)),
    ]);
    _set(() => _ready = true);
  }

  void _set(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = AdminOverviewStats.compute(
      activeRides: _active,
      ridesSinceMonth: _ridesMonth,
      completedSinceMonth: _completedMonth,
      cancelledSinceMonth: _cancelledMonth,
      drivers: _drivers,
      customers: _customers,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isAr ? 'لوحة العمليات' : 'Operations overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          isAr
              ? 'إحصائيات حية لـ Hello Tuk-Tuk'
              : 'Live Hello Tuk-Tuk operations center',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _KpiCard(
              label: isAr ? 'رحلات اليوم' : 'Trips today',
              value: '${stats.tripsToday}',
              color: const Color(0xFF0F766E),
            ),
            _KpiCard(
              label: isAr ? 'رحلات نشطة' : 'Active trips',
              value: '${stats.activeTrips}',
              color: const Color(0xFF2563EB),
            ),
            _KpiCard(
              label: isAr ? 'مكتملة اليوم' : 'Completed today',
              value: '${stats.completedToday}',
              color: const Color(0xFF16A34A),
            ),
            _KpiCard(
              label: isAr ? 'ملغاة اليوم' : 'Cancelled today',
              value: '${stats.cancelledToday}',
              color: const Color(0xFFDC2626),
            ),
            _KpiCard(
              label: isAr ? 'سائقون متصلون' : 'Online drivers',
              value: '${stats.onlineDrivers}',
              color: const Color(0xFF16A34A),
            ),
            _KpiCard(
              label: isAr ? 'سائقون غير متصلين' : 'Offline drivers',
              value: '${stats.offlineDrivers}',
              color: const Color(0xFF64748B),
            ),
            _KpiCard(
              label: isAr ? 'العملاء' : 'Customers',
              value: '${stats.totalCustomers}',
              color: const Color(0xFF7C3AED),
            ),
            _KpiCard(
              label: isAr ? 'السائقون' : 'Drivers',
              value: '${stats.totalDrivers}',
              color: const Color(0xFF0F766E),
            ),
            _KpiCard(
              label: isAr ? 'إيراد اليوم (عمولة)' : 'Daily revenue',
              value: _fare.formatIqd(stats.dailyRevenueIqd, locale: l10n.localeName),
              subtitle:
                  '${isAr ? 'حجم' : 'GMV'}: ${_fare.formatIqd(stats.dailyGmvIqd, locale: l10n.localeName)}',
              color: const Color(0xFFD97706),
              wide: true,
            ),
            _KpiCard(
              label: isAr ? 'إيراد الأسبوع' : 'Weekly revenue',
              value: _fare.formatIqd(stats.weeklyRevenueIqd, locale: l10n.localeName),
              subtitle:
                  '${isAr ? 'حجم' : 'GMV'}: ${_fare.formatIqd(stats.weeklyGmvIqd, locale: l10n.localeName)}',
              color: const Color(0xFFEA580C),
              wide: true,
            ),
            _KpiCard(
              label: isAr ? 'إيراد الشهر' : 'Monthly revenue',
              value: _fare.formatIqd(stats.monthlyRevenueIqd, locale: l10n.localeName),
              subtitle:
                  '${isAr ? 'حجم' : 'GMV'}: ${_fare.formatIqd(stats.monthlyGmvIqd, locale: l10n.localeName)}',
              color: const Color(0xFFB45309),
              wide: true,
            ),
            _KpiCard(
              label: isAr ? 'متوسط تقييم السائق' : 'Avg driver rating',
              value: stats.averageDriverRating.toStringAsFixed(2),
              color: const Color(0xFFEAB308),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final charts = [
              _ChartCard(
                title: isAr ? 'الرحلات / يوم' : 'Trips per day',
                child: _LineChart(
                  values: stats.dayBuckets.map((b) => b.trips.toDouble()).toList(),
                  labels: stats.dayBuckets,
                  color: const Color(0xFF0F766E),
                ),
              ),
              _ChartCard(
                title: isAr ? 'الإيراد (عمولة) / يوم' : 'Revenue / day',
                child: _LineChart(
                  values: stats.dayBuckets
                      .map((b) => b.platformRevenueIqd.toDouble())
                      .toList(),
                  labels: stats.dayBuckets,
                  color: const Color(0xFFD97706),
                ),
              ),
              _ChartCard(
                title: isAr ? 'مستخدمون جدد / يوم' : 'New users / day',
                child: _LineChart(
                  values:
                      stats.dayBuckets.map((b) => b.newUsers.toDouble()).toList(),
                  labels: stats.dayBuckets,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              _ChartCard(
                title: isAr ? 'نشاط السائقين / يوم' : 'Driver activity / day',
                child: _LineChart(
                  values: stats.dayBuckets
                      .map((b) => b.activeDrivers.toDouble())
                      .toList(),
                  labels: stats.dayBuckets,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ];
            if (wide) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[0]),
                      const SizedBox(width: 12),
                      Expanded(child: charts[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: charts[2]),
                      const SizedBox(width: 12),
                      Expanded(child: charts[3]),
                    ],
                  ),
                ],
              );
            }
            return Column(
              children: [
                for (final c in charts) ...[
                  c,
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final widgets = [
              _WidgetCard(
                title: isAr ? 'ملخص العمليات الحية' : 'Live operations summary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${isAr ? 'بحث' : 'Searching'}: ${stats.searchingCount}'),
                    Text('${isAr ? 'معروض' : 'Matched'}: ${stats.matchedCount}'),
                    Text(
                      '${isAr ? 'قيد التنفيذ' : 'In progress'}: ${stats.inProgressCount}',
                    ),
                    Text('${isAr ? 'نشط إجمالي' : 'Active total'}: ${stats.activeTrips}'),
                  ],
                ),
              ),
              _WidgetCard(
                title: isAr ? 'أحدث الرحلات' : 'Recent trips',
                child: _tripList(stats.recentTrips, isAr, l10n.localeName),
              ),
              _WidgetCard(
                title: isAr ? 'تسجيلات العملاء' : 'Recent customers',
                child: _peopleList(
                  stats.recentCustomers
                      .map((c) => MapEntry(c.name, c.phone))
                      .toList(),
                  isAr,
                ),
              ),
              _WidgetCard(
                title: isAr ? 'تسجيلات السائقين' : 'Recent drivers',
                child: _peopleList(
                  stats.recentDrivers
                      .map((d) => MapEntry(d.name, d.phone))
                      .toList(),
                  isAr,
                ),
              ),
              _WidgetCard(
                title: isAr ? 'طلبات شحن المحفظة' : 'Wallet recharge requests',
                child: _pendingRecharges.isEmpty
                    ? Text(isAr ? 'لا طلبات معلّقة' : 'No pending requests')
                    : Column(
                        children: [
                          for (final r in _pendingRecharges.take(6))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                r.driverName.isEmpty ? r.driverId : r.driverName,
                              ),
                              subtitle: Text(
                                '${_fare.formatIqd(r.amountIqd, locale: l10n.localeName)} • ${r.method.value}',
                              ),
                            ),
                        ],
                      ),
              ),
              _WidgetCard(
                title: isAr ? 'الإشعارات' : 'Notifications',
                child: _announcements.isEmpty
                    ? Text(isAr ? 'لا إشعارات بعد' : 'No announcements yet')
                    : Column(
                        children: [
                          for (final a in _announcements.take(6))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(a.title),
                              subtitle: Text(
                                '${a.audience} • ${a.body}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
              ),
              _WidgetCard(
                title: isAr ? 'تنبيهات النظام' : 'System alerts',
                child: _alerts(stats, isAr, l10n.localeName),
              ),
            ];
            if (wide) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final w in widgets)
                    SizedBox(width: (constraints.maxWidth - 12) / 2, child: w),
                ],
              );
            }
            return Column(
              children: [
                for (final w in widgets) ...[
                  w,
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tripList(List<Ride> rides, bool isAr, String locale) {
    if (rides.isEmpty) {
      return Text(isAr ? 'لا رحلات' : 'No trips');
    }
    return Column(
      children: [
        for (final r in rides)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${r.pickupLabel} → ${r.destinationLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${r.status.value} • ${_fare.formatIqd(r.fareAmountIqd, locale: locale)}',
            ),
          ),
      ],
    );
  }

  Widget _peopleList(List<MapEntry<String, String>> rows, bool isAr) {
    if (rows.isEmpty) return Text(isAr ? 'لا بيانات' : 'No data');
    return Column(
      children: [
        for (final row in rows)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(row.key.isEmpty ? '—' : row.key),
            subtitle: Text(row.value),
          ),
      ],
    );
  }

  Widget _alerts(AdminOverviewStats stats, bool isAr, String locale) {
    final items = <String>[];
    for (final d in stats.blockedWalletDrivers) {
      items.add(
        isAr
            ? 'محفظة محظورة: ${d.name}'
            : 'Wallet blocked: ${d.name}',
      );
    }
    for (final d in stats.highDebtDrivers) {
      items.add(
        isAr
            ? 'عمولة مستحقة ${d.name}: ${_fare.formatIqd(d.outstandingPlatformCommissionIqd, locale: locale)}'
            : 'Outstanding commission ${d.name}: ${_fare.formatIqd(d.outstandingPlatformCommissionIqd, locale: locale)}',
      );
    }
    if (items.isEmpty) {
      return Text(isAr ? 'لا تنبيهات حرجة' : 'No critical alerts');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(item, style: const TextStyle(color: Color(0xFFB91C1C))),
          ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.wide = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 280 : 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 180, child: child),
          ],
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<double> values;
  final List<DayBucket> labels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('—'));
    }
    final maxY = values.fold<double>(0, (a, b) => a > b ? a : b);
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (values.length / 4).clamp(1, 7).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  DateFormat('d/M').format(labels[i].day),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
