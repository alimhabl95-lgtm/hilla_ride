import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/core/models/manager_permissions.dart';
import 'package:hilla_ride/features/admin/widgets/admin_assistants_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_customers_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_bonuses_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_earnings_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_leaderboard_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_pricing_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_promo_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_ratings_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_support_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_complaints_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_notifications_center_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_performance_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_reports_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_audit_log_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_app_settings_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_wallet_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_rewards_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_business_partners_panel.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/features/admin/widgets/admin_broadcast_actions.dart';
import 'package:hilla_ride/features/admin/widgets/admin_chrome.dart';
import 'package:hilla_ride/features/admin/widgets/admin_fake_driver_controls.dart';
import 'package:hilla_ride/features/admin/widgets/admin_profile_button.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_card.dart';
import 'package:hilla_ride/features/admin/widgets/admin_global_search.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:hilla_ride/features/admin/widgets/admin_live_map_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_overview_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_service_areas_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_side_nav.dart';
import 'package:hilla_ride/features/admin/screens/admin_ride_detail_screen.dart';
import 'package:hilla_ride/features/admin/screens/admin_ride_status_screen.dart';
import 'package:hilla_ride/features/admin/widgets/admin_ride_promo_summary.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.adminUser});

  final AppUser adminUser;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminTabDefinition {
  const _AdminTabDefinition({
    required this.permission,
    required this.group,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.builder,
  });

  final String permission;
  final AdminNavGroup group;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget builder;

  AdminNavItem toNavItem() => AdminNavItem(
        group: group,
        icon: icon,
        selectedIcon: selectedIcon,
        label: label,
        builder: builder,
      );
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  var _loginAuditLogged = false;
  var _sidebarCollapsed = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _logAdminLoginOnce();
  }

  Future<void> _logAdminLoginOnce() async {
    if (_loginAuditLogged) return;
    _loginAuditLogged = true;
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('logAdminLogin');
      await callable.call();
    } catch (_) {
      // Best-effort audit; dashboard still loads if CF unavailable.
    }
  }

  List<_AdminTabDefinition> _tabs(AppLocalizations l10n) {
    final isAr = l10n.localeName.startsWith('ar');
    final allTabs = <_AdminTabDefinition>[
      _AdminTabDefinition(
        permission: AdminPermissions.overview,
        group: AdminNavGroup.home,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: isAr ? 'الرئيسية' : 'Home',
        builder: const AdminOverviewPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.liveMap,
        group: AdminNavGroup.home,
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: l10n.liveMapTab,
        builder: const AdminLiveMapPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.activeRides,
        group: AdminNavGroup.rides,
        icon: Icons.local_taxi_outlined,
        selectedIcon: Icons.local_taxi,
        label: l10n.activeRidesTab,
        builder: const _ActiveRidesPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.rideHistory,
        group: AdminNavGroup.rides,
        icon: Icons.history,
        selectedIcon: Icons.history,
        label: l10n.rideHistoryTab,
        builder: const _RideHistoryPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.pendingDrivers,
        group: AdminNavGroup.users,
        icon: Icons.pending_actions_outlined,
        selectedIcon: Icons.pending_actions,
        label: l10n.pendingDriversTab,
        builder: const _PendingDriversPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.allDrivers,
        group: AdminNavGroup.users,
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: l10n.allDriversTab,
        builder: _AllDriversPanel(adminUser: widget.adminUser),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.customers,
        group: AdminNavGroup.users,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: l10n.customersTab,
        builder: const AdminCustomersPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.driverReviews,
        group: AdminNavGroup.users,
        icon: Icons.star_outline,
        selectedIcon: Icons.star,
        label: l10n.driverReviewsTab,
        builder: const AdminDriverRatingsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.driverPerformance,
        group: AdminNavGroup.users,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        label: isAr ? 'أداء السائقين' : 'Driver Performance',
        builder: const AdminDriverPerformancePanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.businessPartners,
        group: AdminNavGroup.stores,
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        label: isAr ? 'شركاء الأعمال' : 'Business Partners',
        builder: const AdminBusinessPartnersPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.serviceAreas,
        group: AdminNavGroup.serviceAreas,
        icon: Icons.travel_explore_outlined,
        selectedIcon: Icons.travel_explore,
        label: isAr ? 'مناطق الخدمة' : 'Service areas',
        builder: const AdminServiceAreasPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.earnings,
        group: AdminNavGroup.finance,
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        label: l10n.earningsTab,
        builder: const AdminEarningsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.wallet,
        group: AdminNavGroup.finance,
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        label: l10n.localeName.startsWith('ar') ? 'المحفظة' : 'Wallet',
        builder: const AdminWalletPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.earnings,
        group: AdminNavGroup.finance,
        icon: Icons.card_giftcard_outlined,
        selectedIcon: Icons.card_giftcard,
        label: l10n.driverBonusesTab,
        builder: const AdminBonusesPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.rewards,
        group: AdminNavGroup.rewards,
        icon: Icons.emoji_events_outlined,
        selectedIcon: Icons.emoji_events,
        label: isAr ? 'المكافآت' : 'Rewards',
        builder: const AdminRewardsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.monthlyLeaderboard,
        group: AdminNavGroup.rewards,
        icon: Icons.leaderboard_outlined,
        selectedIcon: Icons.leaderboard,
        label: l10n.monthlyLeaderboardTab,
        builder: const AdminLeaderboardPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.promoCodes,
        group: AdminNavGroup.rewards,
        icon: Icons.local_offer_outlined,
        selectedIcon: Icons.local_offer,
        label: l10n.promoCodesTab,
        builder: const AdminPromoPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.reports,
        group: AdminNavGroup.reports,
        icon: Icons.summarize_outlined,
        selectedIcon: Icons.summarize,
        label: isAr ? 'التقارير' : 'Reports',
        builder: const AdminReportsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.auditLog,
        group: AdminNavGroup.reports,
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        label: isAr ? 'سجل التدقيق' : 'Audit Log',
        builder: const AdminAuditLogPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.pricing,
        group: AdminNavGroup.settings,
        icon: Icons.price_change_outlined,
        selectedIcon: Icons.price_change,
        label: l10n.pricingTab,
        builder: const AdminPricingPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.notifications,
        group: AdminNavGroup.settings,
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: isAr ? 'الإشعارات' : 'Notifications',
        builder: const AdminNotificationsCenterPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.appSettings,
        group: AdminNavGroup.settings,
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: isAr ? 'إعدادات التطبيق' : 'App Settings',
        builder: const AdminAppSettingsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.manageAssistants,
        group: AdminNavGroup.settings,
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
        label: l10n.assistantsTab,
        builder: const AdminAssistantsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.supportInbox,
        group: AdminNavGroup.support,
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        label: l10n.supportInboxTab,
        builder: const AdminSupportPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.complaints,
        group: AdminNavGroup.support,
        icon: Icons.report_problem_outlined,
        selectedIcon: Icons.report_problem,
        label: isAr ? 'الشكاوى' : 'Complaints',
        builder: const AdminComplaintsPanel(),
      ),
    ];

    return allTabs
        .where((tab) => widget.adminUser.hasAdminPermission(tab.permission))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final isTablet = width >= 700 && width < 900;
    final tabs = _tabs(l10n);

    if (tabs.isEmpty) {
      return Scaffold(
        body: Center(child: Text(l10n.assistantNoPermissions)),
      );
    }

    if (_selectedIndex >= tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    }

    final safeIndex = _selectedIndex.clamp(0, tabs.length - 1);
    final selected = tabs[safeIndex];
    final navItems = tabs.map((t) => t.toNavItem()).toList();
    final dateLabel = DateFormat.yMMMMEEEEd(l10n.localeName).format(DateTime.now());

    void selectTab(int index) {
      setState(() => _selectedIndex = index);
      if (!isWide) {
        _scaffoldKey.currentState?.closeDrawer();
      }
    }

    final sideNav = AdminSideNav(
      items: navItems,
      selectedIndex: safeIndex,
      collapsed: isWide && _sidebarCollapsed,
      onToggleCollapse: isWide
          ? () => setState(() => _sidebarCollapsed = !_sidebarCollapsed)
          : null,
      onSelected: selectTab,
      width: isTablet ? 220 : 260,
    );

    final baseTheme = Theme.of(context);
    final adminTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: AdminChrome.contentBg,
      cardTheme: baseTheme.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AdminChrome.cardBorder),
        ),
      ),
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: AppBrandAssets.brandTeal,
        secondary: AppBrandAssets.brandTealDark,
      ),
    );

    return Theme(
      data: adminTheme,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AdminChrome.contentBg,
        drawer: isWide
            ? null
            : Drawer(
                backgroundColor: AdminChrome.sidebarBg,
                width: 280,
                child: SafeArea(
                  child: AdminSideNav(
                    items: navItems,
                    selectedIndex: safeIndex,
                    onSelected: selectTab,
                    width: 280,
                  ),
                ),
              ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isWide) sideNav,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: AdminChrome.cardBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (!isWide)
                              IconButton(
                                tooltip: isAr ? 'القائمة' : 'Menu',
                                onPressed: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                                icon: const Icon(Icons.menu),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selected.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF111827),
                                        ),
                                  ),
                                  Text(
                                    dateLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AdminChrome.sidebarMuted,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (isWide || isTablet)
                              const SizedBox(
                                width: 280,
                                child: AdminGlobalSearchField(),
                              )
                            else
                              const AdminGlobalSearchField(compact: true),
                            const SizedBox(width: 8),
                            if (widget.adminUser.hasAdminPermission(
                              AdminPermissions.rideHistory,
                            )) ...[
                              IconButton(
                                tooltip: l10n.completedRidesCount,
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminRideStatusScreen(
                                        status: RideStatus.completed,
                                        title: l10n.completedRidesCount,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: l10n.cancelledRidesCount,
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminRideStatusScreen(
                                        status: RideStatus.cancelled,
                                        title: l10n.cancelledRidesCount,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                            AdminBroadcastActions(adminUser: widget.adminUser),
                            const AdminProfileButton(),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: selected.builder),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDriversPanel extends StatefulWidget {
  const _PendingDriversPanel();

  @override
  State<_PendingDriversPanel> createState() => _PendingDriversPanelState();
}

class _PendingDriversPanelState extends State<_PendingDriversPanel> {
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  bool _matchesDriverFilter(DriverProfile driver) {
    final catalog = ServiceAreaCatalog.instance;
    if (!_filters.matchesGeo(
      provinceId: catalog.provinceIdForDistrict(driver.assignedDistrictId),
      districtId: driver.assignedDistrictId,
      subDistrictId: driver.assignedSubDistrictId,
    )) {
      return false;
    }
    return _filters.matchesDate(driver.createdAt);
  }

  Widget _bonusBanner(BuildContext context, bool isAr, int bonusIqd) {
    if (bonusIqd <= 0) return const SizedBox.shrink();
    final fare = FareService();
    final amount = fare.formatIqd(
      bonusIqd,
      locale: isAr ? 'ar' : 'en',
    );
    return Material(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFF059669)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr
                    ? 'الموافقة تضيف $amount تلقائياً لمحفظة السائق'
                    : 'Approving credits $amount to the driver wallet automatically',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF065F46),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');
    final adminService = context.read<AppState>().adminService;
    final walletService = context.read<AppState>().walletService;

    return StreamBuilder<WalletConfig>(
      stream: walletService.watchConfig(),
      builder: (context, walletSnap) {
        final bonusIqd = walletSnap.data?.registrationBonusIqd ?? 0;
        return StreamBuilder<List<DriverProfile>>(
          stream: adminService.watchAllDrivers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        l10n.pendingDriversLoadError,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }

            final drivers = (snapshot.data ?? const [])
                .where((driver) =>
                    driver.approvalStatus == DriverApprovalStatus.pending)
                .where(_matchesDriverFilter)
                .toList()
              ..sort(
                (a, b) =>
                    (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                        .compareTo(
                            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
              );

            if (drivers.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _bonusBanner(context, isAr, bonusIqd),
                        if (bonusIqd > 0) const SizedBox(height: 12),
                        AdminFilterBar(
                          value: _filters,
                          onChanged: (v) => setState(() => _filters = v),
                          fields: const [
                            AdminFilterField.province,
                            AdminFilterField.district,
                            AdminFilterField.subDistrict,
                            AdminFilterField.dateRange,
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(l10n.noPendingDrivers,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Text(
                              l10n.checkAllDriversTab,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: drivers.length + 1,
              separatorBuilder: (_, index) {
                if (index == 0) return const SizedBox(height: 12);
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _bonusBanner(context, isAr, bonusIqd),
                      if (bonusIqd > 0) const SizedBox(height: 12),
                      AdminFilterBar(
                        value: _filters,
                        onChanged: (v) => setState(() => _filters = v),
                        fields: const [
                          AdminFilterField.province,
                          AdminFilterField.district,
                          AdminFilterField.subDistrict,
                          AdminFilterField.dateRange,
                        ],
                      ),
                    ],
                  );
                }
                return AdminDriverCard(driver: drivers[index - 1]);
              },
            );
          },
        );
      },
    );
  }
}

class _ActiveRidesPanel extends StatefulWidget {
  const _ActiveRidesPanel();

  @override
  State<_ActiveRidesPanel> createState() => _ActiveRidesPanelState();
}

class _ActiveRidesPanelState extends State<_ActiveRidesPanel> {
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    final catalog = ServiceAreaCatalog.instance;

    return StreamBuilder<List<Ride>>(
      stream: adminService.watchActiveRides(),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? const [];
        final filtered = rides.where((ride) {
          if (!_filters.matchesGeo(
            provinceId: catalog.provinceIdForDistrict(ride.districtId),
            districtId: ride.districtId,
            subDistrictId: ride.subDistrictId,
          )) {
            return false;
          }
          if (_filters.rideStatus != null &&
              ride.status.value != _filters.rideStatus) {
            return false;
          }
          return _filters.matchesDate(ride.createdAt);
        }).toList();

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
                AdminFilterField.rideStatus,
                AdminFilterField.dateRange,
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.noActiveRides))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _RideCard(
                        ride: filtered[index],
                        localeName: l10n.localeName,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AllDriversPanel extends StatefulWidget {
  const _AllDriversPanel({required this.adminUser});

  final AppUser adminUser;

  @override
  State<_AllDriversPanel> createState() => _AllDriversPanelState();
}

class _AllDriversPanelState extends State<_AllDriversPanel> {
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  bool _matchesDriverFilter(DriverProfile driver) {
    final catalog = ServiceAreaCatalog.instance;
    if (!_filters.matchesGeo(
      provinceId: catalog.provinceIdForDistrict(driver.assignedDistrictId),
      districtId: driver.assignedDistrictId,
      subDistrictId: driver.assignedSubDistrictId,
    )) {
      return false;
    }
    if (_filters.driverStatus != null) {
      final status = _filters.driverStatus!;
      switch (status) {
        case 'online':
          if (!driver.isOnline) return false;
        case 'offline':
          if (driver.isOnline) return false;
        case 'approved':
          if (!driver.isApproved) return false;
        case 'pending':
          if (driver.approvalStatus != DriverApprovalStatus.pending) {
            return false;
          }
        case 'blocked':
          if (!driver.isBlocked) return false;
        case 'busy':
          if (!driver.hasActiveRide) return false;
      }
    }
    return _filters.matchesDate(driver.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    final isManager = widget.adminUser.isOwnerManager;

    return StreamBuilder<List<DriverProfile>>(
      stream: adminService.watchAllDrivers(),
      builder: (context, snapshot) {
        final drivers = List<DriverProfile>.from(snapshot.data ?? const [])
          ..retainWhere(_matchesDriverFilter)
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: drivers.isEmpty ? 2 : drivers.length + 2,
          separatorBuilder: (_, index) {
            if (index <= 1) return const SizedBox(height: 12);
            return const SizedBox(height: 12);
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return AdminFilterBar(
                value: _filters,
                onChanged: (v) => setState(() => _filters = v),
                fields: const [
                  AdminFilterField.province,
                  AdminFilterField.district,
                  AdminFilterField.subDistrict,
                  AdminFilterField.driverStatus,
                  AdminFilterField.dateRange,
                ],
              );
            }
            if (index == 1) {
              return AdminFakeDriverBar(isManager: isManager);
            }
            if (drivers.isEmpty) {
              return Center(child: Text(l10n.noDriversYet));
            }
            final driver = drivers[index - 2];
            return AdminDriverCard(
              driver: driver,
              isManager: isManager,
            );
          },
        );
      },
    );
  }
}

class _RideHistoryPanel extends StatefulWidget {
  const _RideHistoryPanel();

  @override
  State<_RideHistoryPanel> createState() => _RideHistoryPanelState();
}

class _RideHistoryPanelState extends State<_RideHistoryPanel> {
  AdminFilterCriteria _filters = AdminFilterCriteria.empty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    const fareService = FareService();
    final catalog = ServiceAreaCatalog.instance;
    final isAr = l10n.localeName.startsWith('ar');

    return StreamBuilder<List<Ride>>(
      stream: adminService.watchRecentRides(),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? const [];
        final filtered = rides.where((ride) {
          if (!_filters.matchesGeo(
            provinceId: catalog.provinceIdForDistrict(ride.districtId),
            districtId: ride.districtId,
            subDistrictId: ride.subDistrictId,
          )) {
            return false;
          }
          if (_filters.rideStatus != null &&
              ride.status.value != _filters.rideStatus) {
            return false;
          }
          final q = _filters.query.trim().toLowerCase();
          if (q.isNotEmpty) {
            final haystack =
                '${ride.rideNumber} ${ride.id} ${ride.pickupLabel} ${ride.destinationLabel}'
                    .toLowerCase();
            if (!haystack.contains(q)) return false;
          }
          final when = ride.completedAt ?? ride.createdAt;
          return _filters.matchesDate(when);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminFilterBar(
              value: _filters,
              onChanged: (v) => setState(() => _filters = v),
              hintText: l10n.searchRideByNumber,
              fields: const [
                AdminFilterField.province,
                AdminFilterField.district,
                AdminFilterField.subDistrict,
                AdminFilterField.rideStatus,
                AdminFilterField.dateRange,
                AdminFilterField.search,
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(l10n.noRideHistory))
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ride = filtered[index];
                        final when = ride.completedAt ?? ride.createdAt;
                        final dateLabel = when == null
                            ? '—'
                            : DateFormat.yMMMd(l10n.localeName)
                                .add_jm()
                                .format(when);
                        final cityLabel = ride.districtId.isEmpty
                            ? ''
                            : catalog.localizedDistrictName(
                                ride.districtId,
                                isAr: isAr,
                              );
                        final subLabel = ride.subDistrictId.isEmpty
                            ? ''
                            : catalog.localizedSubName(
                                ride.subDistrictId,
                                isAr: isAr,
                              );

                        return ListTile(
                          title: Text(
                            ride.rideNumber.isNotEmpty
                                ? '${l10n.rideNumberLabel(ride.rideNumber)} • ${ride.pickupLabel} → ${ride.destinationLabel}'
                                : '${ride.pickupLabel} → ${ride.destinationLabel}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l10n.tripDateTime}: $dateLabel'),
                              Text(
                                [
                                  if (cityLabel.isNotEmpty) cityLabel,
                                  if (subLabel.isNotEmpty) subLabel,
                                  ride.status.name,
                                  fareService.formatIqd(
                                    ride.fareAmountIqd,
                                    locale: l10n.localeName,
                                  ),
                                ].join(' • '),
                              ),
                              AdminRidePromoSummary(ride: ride, compact: true),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AdminRideDetailScreen(ride: ride),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.ride,
    this.localeName = 'en',
  });

  final Ride ride;
  final String localeName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const fareService = FareService();
    final catalog = ServiceAreaCatalog.instance;
    final isAr = localeName.startsWith('ar');
    final cityLabel = ride.districtId.isEmpty
        ? ''
        : catalog.localizedDistrictName(ride.districtId, isAr: isAr);
    final subLabel = ride.subDistrictId.isEmpty
        ? ''
        : catalog.localizedSubName(ride.subDistrictId, isAr: isAr);

    return Card(
      child: ListTile(
        title: Text(
          ride.rideNumber.isNotEmpty
              ? '${l10n.rideNumberLabel(ride.rideNumber)} • ${ride.pickupLabel} → ${ride.destinationLabel}'
              : '${ride.pickupLabel} → ${ride.destinationLabel}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ride.createdAt != null)
              Text(
                '${l10n.tripDateTime}: ${DateFormat.yMMMd(l10n.localeName).add_jm().format(ride.createdAt!)}',
              ),
            if (cityLabel.isNotEmpty || subLabel.isNotEmpty)
              Text(
                [
                  if (cityLabel.isNotEmpty) cityLabel,
                  if (subLabel.isNotEmpty) subLabel,
                ].join(' • '),
              ),
            Text(
              '${ride.status.name} • ${fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}',
            ),
            AdminRidePromoSummary(ride: ride, compact: true),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminRideDetailScreen(ride: ride),
          ),
        ),
      ),
    );
  }
}
