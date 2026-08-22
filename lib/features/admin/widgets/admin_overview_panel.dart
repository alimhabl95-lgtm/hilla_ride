import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:hilla_ride/core/models/promo_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/admin_stats_service.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/features/admin/widgets/admin_chrome.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
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
  List<WalletWithdrawalRequest> _pendingWithdrawals = const [];
  List<Announcement> _announcements = const [];
  List<BusinessPartner> _businesses = const [];
  List<BusinessOrder> _orders = const [];
  WalletConfig _walletConfig = const WalletConfig();
  LoyaltyConfig _loyaltyConfig = const LoyaltyConfig();
  final _subs = <StreamSubscription>[];
  var _ready = false;
  var _showAllMetrics = false;
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  void _bind() {
    final app = context.read<AppState>();
    final admin = app.adminService;
    final wallet = app.walletService;
    final business = app.businessService;
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
      wallet
          .watchWithdrawalRequests(status: 'pending')
          .listen((v) => _set(() => _pendingWithdrawals = v)),
      wallet.watchConfig().listen((v) => _set(() => _walletConfig = v)),
      app.promoService
          .watchLoyaltyConfig()
          .listen((v) => _set(() => _loyaltyConfig = v)),
      admin
          .watchRecentAnnouncements()
          .listen((v) => _set(() => _announcements = v)),
      business.watchBusinesses().listen((v) => _set(() => _businesses = v)),
      business.watchAllOrders().listen((v) => _set(() => _orders = v)),
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

    final catalog = ServiceAreaCatalog.instance;

    bool rideMatches(Ride r) {
      if (!_filters.matchesGeo(
        provinceId: catalog.provinceIdForDistrict(r.districtId),
        districtId: r.districtId,
        subDistrictId: r.subDistrictId,
      )) {
        return false;
      }
      return _filters.matchesDate(r.createdAt);
    }

    bool driverMatches(DriverProfile d) {
      return _filters.matchesGeo(
        provinceId: catalog.provinceIdForDistrict(d.assignedDistrictId),
        districtId: d.assignedDistrictId,
        subDistrictId: d.assignedSubDistrictId,
      );
    }

    bool businessMatches(BusinessPartner b) {
      if (!_filters.matchesGeo(
        provinceId: b.provinceId,
        districtId: b.districtId,
        subDistrictId: b.subDistrictId,
      )) {
        return false;
      }
      return _filters.matchesDate(b.createdAt);
    }

    bool orderMatches(BusinessOrder o) {
      if (!_filters.matchesGeo(
        districtId: o.districtId,
        subDistrictId: o.subDistrictId,
      )) {
        return false;
      }
      return _filters.matchesDate(o.createdAt);
    }

    final active = _active.where(rideMatches).toList();
    final ridesMonth = _ridesMonth.where(rideMatches).toList();
    final completedMonth = _completedMonth.where(rideMatches).toList();
    final cancelledMonth = _cancelledMonth.where(rideMatches).toList();
    final drivers = _drivers.where(driverMatches).toList();
    final businesses = _businesses.where(businessMatches).toList();
    final orders = _orders.where(orderMatches).toList();
    final driversById = {for (final d in _drivers) d.uid: d};
    final pendingRecharges = _pendingRecharges.where((req) {
      if (!_filters.hasGeo && !_filters.hasDateRange) return true;
      final district = req.districtId.isNotEmpty
          ? req.districtId
          : (driversById[req.driverId]?.assignedDistrictId ?? '');
      final sub = driversById[req.driverId]?.assignedSubDistrictId ?? '';
      if (!_filters.matchesGeo(districtId: district, subDistrictId: sub)) {
        return false;
      }
      return _filters.matchesDate(req.createdAt);
    }).toList();

    final stats = AdminOverviewStats.compute(
      activeRides: active,
      ridesSinceMonth: ridesMonth,
      completedSinceMonth: completedMonth,
      cancelledSinceMonth: cancelledMonth,
      drivers: drivers,
      customers: _customers,
      businesses: businesses,
      orders: orders,
    );

    final pendingDrivers = drivers
        .where((d) => !d.isApproved && !d.isRemoved)
        .length;
    final pendingPartners =
        businesses.where((b) => b.status == BusinessStatus.pendingReview).length;
    final alertCount = pendingRecharges.length +
        _pendingWithdrawals.length +
        pendingDrivers +
        pendingPartners +
        stats.blockedWalletDrivers.length +
        stats.highDebtDrivers.length;
    final recentOrders = [...orders]
      ..sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    final onlineDrivers = drivers
        .where((d) => d.isOnline && d.isApproved && !d.isRemoved)
        .take(8)
        .toList();
    final last7 = stats.dayBuckets.length > 7
        ? stats.dayBuckets.sublist(stats.dayBuckets.length - 7)
        : stats.dayBuckets;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          isAr ? 'مرحباً بك في لوحة الإدارة' : 'Welcome to the admin console',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppBrandAssets.brandNavy,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          isAr
              ? 'نظرة حية على الرحلات والطلبات والإيرادات والتنبيهات'
              : 'Live view of rides, orders, revenue, and alerts',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppBrandAssets.brandMuted,
              ),
        ),
        const SizedBox(height: 12),
        AdminFilterBar(
          value: _filters,
          onChanged: (v) => setState(() => _filters = v),
          margin: EdgeInsets.zero,
          fields: const [
            AdminFilterField.province,
            AdminFilterField.district,
            AdminFilterField.subDistrict,
            AdminFilterField.dateRange,
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1200
                ? 6
                : constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                        ? 2
                        : 1;
            final gap = 12.0;
            final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
            final primary = [
              AdminKpiTile(
                icon: Icons.person_add_alt_1_outlined,
                label: isAr ? 'سائقون بانتظار الموافقة' : 'Pending drivers',
                value: '$pendingDrivers',
                accent: AdminChrome.danger,
                subtitle: isAr ? 'راجع طلبات التسجيل' : 'Review registrations',
              ),
              AdminKpiTile(
                icon: Icons.local_taxi_outlined,
                label: isAr ? 'رحلات اليوم' : "Today's rides",
                value: '${stats.tripsToday}',
                accent: AppBrandAssets.brandTeal,
                subtitle:
                    '${isAr ? 'نشطة' : 'Active'}: ${stats.activeTrips}',
              ),
              AdminKpiTile(
                icon: Icons.wifi_tethering,
                label: isAr ? 'سائقون متصلون' : 'Online drivers',
                value: '${stats.onlineDrivers}',
                accent: AdminChrome.success,
                subtitle:
                    '${isAr ? 'غير متصلين' : 'Offline'}: ${stats.offlineDrivers}',
              ),
              AdminKpiTile(
                icon: Icons.people_outline,
                label: isAr ? 'إجمالي العملاء' : 'Total customers',
                value: NumberFormat.decimalPattern(l10n.localeName)
                    .format(stats.totalCustomers),
                accent: const Color(0xFF7C3AED),
              ),
              AdminKpiTile(
                icon: Icons.payments_outlined,
                label: isAr ? 'إيراد اليوم' : "Today's revenue",
                value: _fare.formatIqd(
                  stats.dailyRevenueIqd,
                  locale: l10n.localeName,
                ),
                accent: const Color(0xFFD97706),
                subtitle:
                    '${isAr ? 'حجم' : 'GMV'}: ${_fare.formatIqd(stats.dailyGmvIqd, locale: l10n.localeName)}',
              ),
              AdminKpiTile(
                icon: Icons.warning_amber_rounded,
                label: isAr ? 'يحتاج انتباه' : 'Needs attention',
                value: '$alertCount',
                accent: AdminChrome.danger,
                subtitle: isAr
                    ? 'عناصر تتطلب مراجعة'
                    : 'Items need review',
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tile in primary)
                  SizedBox(width: tileW, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _showAllMetrics = !_showAllMetrics),
            icon: Icon(
              _showAllMetrics ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(
              _showAllMetrics
                  ? (isAr ? 'إخفاء المقاييس الإضافية' : 'Hide extra metrics')
                  : (isAr ? 'عرض كل المقاييس' : 'Show all metrics'),
            ),
          ),
        ),
        if (_showAllMetrics) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniMetric(
                label: isAr ? 'مكافأة التسجيل' : 'Registration bonus',
                value: _walletConfig.registrationBonusIqd <= 0
                    ? (isAr ? 'معطّل' : 'Off')
                    : _fare.formatIqd(
                        _walletConfig.registrationBonusIqd,
                        locale: l10n.localeName,
                      ),
              ),
              _MiniMetric(
                label: isAr ? 'ولاء العملاء' : 'Customer loyalty',
                value: _loyaltyConfig.summary(isAr),
              ),
              _MiniMetric(
                label: isAr ? 'مكتملة اليوم' : 'Completed today',
                value: '${stats.completedToday}',
              ),
              _MiniMetric(
                label: isAr ? 'ملغاة اليوم' : 'Cancelled today',
                value: '${stats.cancelledToday}',
              ),
              _MiniMetric(
                label: isAr ? 'إيراد التوصيل' : 'Delivery revenue',
                value: _fare.formatIqd(
                  stats.deliveryRevenueIqd,
                  locale: l10n.localeName,
                ),
              ),
              _MiniMetric(
                label: isAr ? 'رصيد المحافظ' : 'Wallet balance',
                value: _fare.formatIqd(
                  stats.walletBalanceTotalIqd,
                  locale: l10n.localeName,
                ),
              ),
              _MiniMetric(
                label: isAr ? 'المكافآت الممنوحة' : 'Rewards issued',
                value: _fare.formatIqd(
                  stats.rewardsIssuedIqd,
                  locale: l10n.localeName,
                ),
              ),
              _MiniMetric(
                label: isAr ? 'مطاعم نشطة' : 'Restaurants',
                value: '${stats.activeRestaurants}',
              ),
              _MiniMetric(
                label: isAr ? 'سوبرماركت' : 'Supermarkets',
                value: '${stats.activeSupermarkets}',
              ),
              _MiniMetric(
                label: isAr ? 'صيدليات' : 'Pharmacies',
                value: '${stats.activePharmacies}',
              ),
              _MiniMetric(
                label: isAr ? 'أعمال نشطة' : 'Businesses',
                value: '${stats.activeBusinesses}',
              ),
              _MiniMetric(
                label: isAr ? 'السائقون' : 'Drivers',
                value: '${stats.totalDrivers}',
              ),
              _MiniMetric(
                label: isAr ? 'إيراد الأسبوع' : 'Weekly revenue',
                value: _fare.formatIqd(
                  stats.weeklyRevenueIqd,
                  locale: l10n.localeName,
                ),
              ),
              _MiniMetric(
                label: isAr ? 'إيراد الشهر' : 'Monthly revenue',
                value: _fare.formatIqd(
                  stats.monthlyRevenueIqd,
                  locale: l10n.localeName,
                ),
              ),
              _MiniMetric(
                label: isAr ? 'متوسط التقييم' : 'Avg rating',
                value: stats.averageDriverRating.toStringAsFixed(2),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            final mid = constraints.maxWidth >= 800;
            final revenueCard = AdminSurfaceCard(
              title: isAr ? 'الإيراد (آخر 7 أيام)' : 'Revenue (last 7 days)',
              child: SizedBox(
                height: 220,
                child: _LineChart(
                  values: last7
                      .map((b) => b.platformRevenueIqd.toDouble())
                      .toList(),
                  labels: last7,
                  color: AppBrandAssets.brandTeal,
                ),
              ),
            );
            final ordersCard = AdminSurfaceCard(
              title: isAr ? 'نظرة على الطلبات' : 'Orders overview',
              child: SizedBox(
                height: 220,
                child: _OrdersDonut(orders: orders, isAr: isAr),
              ),
            );
            final alertsCard = AdminSurfaceCard(
              title: isAr ? 'مهام عاجلة' : 'Needs attention',
              child: _urgentTasks(
                isAr: isAr,
                pendingWithdrawals: _pendingWithdrawals.length,
                pendingRecharges: pendingRecharges.length,
                pendingDrivers: pendingDrivers,
                pendingPartners: pendingPartners,
                blockedWallets: stats.blockedWalletDrivers.length,
                highDebt: stats.highDebtDrivers.length,
                searching: stats.searchingCount,
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: revenueCard),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: ordersCard),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: alertsCard),
                ],
              );
            }
            if (mid) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: revenueCard),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: ordersCard),
                    ],
                  ),
                  const SizedBox(height: 12),
                  alertsCard,
                ],
              );
            }
            return Column(
              children: [
                revenueCard,
                const SizedBox(height: 12),
                ordersCard,
                const SizedBox(height: 12),
                alertsCard,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            final mid = constraints.maxWidth >= 800;
            final ridesCard = AdminSurfaceCard(
              title: isAr ? 'أحدث الرحلات' : 'Recent rides',
              child: _tripList(stats.recentTrips, isAr, l10n.localeName),
            );
            final ordersCard = AdminSurfaceCard(
              title: isAr ? 'أحدث طلبات المتاجر' : 'Recent store orders',
              child: _orderList(recentOrders.take(8).toList(), isAr, l10n.localeName),
            );
            final driversCard = AdminSurfaceCard(
              title: isAr ? 'سائقون متصلون' : 'Online drivers',
              child: _onlineDriversList(onlineDrivers, isAr),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ridesCard),
                  const SizedBox(width: 12),
                  Expanded(child: ordersCard),
                  const SizedBox(width: 12),
                  Expanded(child: driversCard),
                ],
              );
            }
            if (mid) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ridesCard),
                      const SizedBox(width: 12),
                      Expanded(child: ordersCard),
                    ],
                  ),
                  const SizedBox(height: 12),
                  driversCard,
                ],
              );
            }
            return Column(
              children: [
                ridesCard,
                const SizedBox(height: 12),
                ordersCard,
                const SizedBox(height: 12),
                driversCard,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
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
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < charts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: charts[i]),
                  ],
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
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            final widgets = [
              AdminSurfaceCard(
                title: isAr ? 'ملخص العمليات الحية' : 'Live operations summary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _opsRow(isAr ? 'بحث' : 'Searching', stats.searchingCount),
                    _opsRow(isAr ? 'معروض' : 'Matched', stats.matchedCount),
                    _opsRow(
                      isAr ? 'قيد التنفيذ' : 'In progress',
                      stats.inProgressCount,
                    ),
                    _opsRow(isAr ? 'نشط إجمالي' : 'Active total', stats.activeTrips),
                  ],
                ),
              ),
              AdminSurfaceCard(
                title: isAr ? 'تسجيلات العملاء' : 'Recent customers',
                child: _peopleList(
                  stats.recentCustomers
                      .map((c) => MapEntry(c.name, c.phone))
                      .toList(),
                  isAr,
                ),
              ),
              AdminSurfaceCard(
                title: isAr ? 'تسجيلات السائقين' : 'Recent drivers',
                child: _peopleList(
                  stats.recentDrivers
                      .map((d) => MapEntry(d.name, d.phone))
                      .toList(),
                  isAr,
                ),
              ),
              AdminSurfaceCard(
                title: isAr ? 'طلبات شحن المحفظة' : 'Wallet recharge requests',
                child: pendingRecharges.isEmpty
                    ? Text(isAr ? 'لا طلبات معلّقة' : 'No pending requests')
                    : Column(
                        children: [
                          for (final r in pendingRecharges.take(6))
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
              AdminSurfaceCard(
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
              AdminSurfaceCard(
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
                    SizedBox(
                      width: (constraints.maxWidth - 12) / 2,
                      child: w,
                    ),
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

  Widget _opsRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _urgentTasks({
    required bool isAr,
    required int pendingWithdrawals,
    required int pendingRecharges,
    required int pendingDrivers,
    required int pendingPartners,
    required int blockedWallets,
    required int highDebt,
    required int searching,
  }) {
    final items = <({String label, int count, Color color})>[
      (
        label: isAr ? 'طلبات سحب بانتظار الموافقة' : 'Withdrawal requests pending',
        count: pendingWithdrawals,
        color: AdminChrome.danger,
      ),
      (
        label: isAr ? 'طلبات شحن معلّقة' : 'Recharge requests pending',
        count: pendingRecharges,
        color: AdminChrome.warning,
      ),
      (
        label: isAr ? 'سائقون بانتظار التفعيل' : 'Drivers pending activation',
        count: pendingDrivers,
        color: AdminChrome.info,
      ),
      (
        label: isAr ? 'شركاء بانتظار المراجعة' : 'Partners pending review',
        count: pendingPartners,
        color: const Color(0xFF7C3AED),
      ),
      (
        label: isAr ? 'محافظ محظورة' : 'Blocked wallets',
        count: blockedWallets,
        color: AdminChrome.danger,
      ),
      (
        label: isAr ? 'ديون عمولة مرتفعة' : 'High commission debt',
        count: highDebt,
        color: AdminChrome.warning,
      ),
      (
        label: isAr ? 'رحلات تبحث عن سائق' : 'Rides searching',
        count: searching,
        color: AppBrandAssets.brandTeal,
      ),
    ];
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.count}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: item.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _StatusChip(label: r.status.value),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.pickupLabel} → ${r.destinationLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _fare.formatIqd(r.fareAmountIqd, locale: locale),
                        style: const TextStyle(
                          color: AppBrandAssets.brandMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _orderList(List<BusinessOrder> orders, bool isAr, String locale) {
    if (orders.isEmpty) {
      return Text(isAr ? 'لا طلبات' : 'No orders');
    }
    return Column(
      children: [
        for (final o in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                _StatusChip(label: o.status.name),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.businessName.isEmpty
                            ? (isAr ? 'متجر' : 'Store')
                            : o.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '#${o.id.length > 6 ? o.id.substring(0, 6) : o.id}'
                        ' • ${_fare.formatIqd(o.totalIqd, locale: locale)}',
                        style: const TextStyle(
                          color: AppBrandAssets.brandMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _onlineDriversList(List<DriverProfile> drivers, bool isAr) {
    if (drivers.isEmpty) {
      return Text(isAr ? 'لا سائقين متصلين' : 'No online drivers');
    }
    return Column(
      children: [
        for (final d in drivers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppBrandAssets.brandTeal.withValues(alpha: 0.15),
                  child: Text(
                    (d.name.isNotEmpty ? d.name[0] : '?').toUpperCase(),
                    style: const TextStyle(
                      color: AppBrandAssets.brandTeal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name.isEmpty ? d.uid : d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '★ ${d.rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: AppBrandAssets.brandMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AdminChrome.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isAr ? 'متصل' : 'Online',
                    style: const TextStyle(
                      color: AdminChrome.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
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

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: AdminSurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppBrandAssets.brandMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lower = label.toLowerCase();
    Color color = AdminChrome.info;
    if (lower.contains('complet') ||
        lower.contains('deliver') ||
        lower.contains('مكتمل')) {
      color = AdminChrome.success;
    } else if (lower.contains('cancel') || lower.contains('ملغ')) {
      color = AdminChrome.danger;
    } else if (lower.contains('progress') ||
        lower.contains('ready') ||
        lower.contains('search') ||
        lower.contains('pending')) {
      color = AdminChrome.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
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
    return AdminSurfaceCard(
      title: title,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: SizedBox(height: 180, child: child),
    );
  }
}

class _OrdersDonut extends StatelessWidget {
  const _OrdersDonut({required this.orders, required this.isAr});

  final List<BusinessOrder> orders;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final counts = <BusinessOrderStatus, int>{};
    for (final o in orders) {
      counts[o.status] = (counts[o.status] ?? 0) + 1;
    }
    final total = orders.length;
    if (total == 0) {
      return Center(child: Text(isAr ? 'لا طلبات' : 'No orders'));
    }

    final palette = <BusinessOrderStatus, Color>{
      BusinessOrderStatus.pending: AdminChrome.warning,
      BusinessOrderStatus.accepted: const Color(0xFF06B6D4),
      BusinessOrderStatus.preparing: AdminChrome.info,
      BusinessOrderStatus.ready: AppBrandAssets.brandTeal,
      BusinessOrderStatus.outForDelivery: const Color(0xFF2563EB),
      BusinessOrderStatus.delivered: AdminChrome.success,
      BusinessOrderStatus.cancelled: AdminChrome.danger,
      BusinessOrderStatus.rejected: AdminChrome.danger,
    };

    final sections = counts.entries
        .where((e) => e.value > 0)
        .map(
          (e) => PieChartSectionData(
            value: e.value.toDouble(),
            color: palette[e.key] ?? AdminChrome.info,
            radius: 48,
            title: '',
          ),
        )
        .toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isAr ? 'الإجمالي $total' : 'Total $total',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final e in counts.entries.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette[e.key] ?? AdminChrome.info,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${e.key.name} (${e.value})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
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
