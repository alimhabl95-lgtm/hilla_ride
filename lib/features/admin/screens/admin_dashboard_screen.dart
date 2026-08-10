import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/models/admin_filter_models.dart';
import 'package:hilla_ride/core/models/app_models.dart';
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
import 'package:hilla_ride/features/admin/widgets/admin_broadcast_actions.dart';
import 'package:hilla_ride/features/admin/widgets/admin_fake_driver_controls.dart';
import 'package:hilla_ride/features/admin/widgets/admin_profile_button.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_card.dart';
import 'package:hilla_ride/features/admin/widgets/admin_global_search.dart';
import 'package:hilla_ride/features/admin/widgets/admin_filter_bar.dart';
import 'package:hilla_ride/features/admin/widgets/admin_live_map_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_overview_panel.dart';
import 'package:hilla_ride/features/admin/widgets/admin_service_areas_panel.dart';
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
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.builder,
  });

  final String permission;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget builder;
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  var _loginAuditLogged = false;

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
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: isAr ? 'نظرة عامة' : 'Overview',
        builder: const AdminOverviewPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.pendingDrivers,
        icon: Icons.pending_actions_outlined,
        selectedIcon: Icons.pending_actions,
        label: l10n.pendingDriversTab,
        builder: const _PendingDriversPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.activeRides,
        icon: Icons.local_taxi_outlined,
        selectedIcon: Icons.local_taxi,
        label: l10n.activeRidesTab,
        builder: const _ActiveRidesPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.liveMap,
        icon: Icons.map_outlined,
        selectedIcon: Icons.map,
        label: l10n.liveMapTab,
        builder: const AdminLiveMapPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.allDrivers,
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: l10n.allDriversTab,
        builder: _AllDriversPanel(adminUser: widget.adminUser),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.customers,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: l10n.customersTab,
        builder: const AdminCustomersPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.rideHistory,
        icon: Icons.history,
        selectedIcon: Icons.history,
        label: l10n.rideHistoryTab,
        builder: const _RideHistoryPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.pricing,
        icon: Icons.price_change_outlined,
        selectedIcon: Icons.price_change,
        label: l10n.pricingTab,
        builder: const AdminPricingPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.serviceAreas,
        icon: Icons.travel_explore_outlined,
        selectedIcon: Icons.travel_explore,
        label: isAr ? 'مناطق الخدمة' : 'Service areas',
        builder: const AdminServiceAreasPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.promoCodes,
        icon: Icons.local_offer_outlined,
        selectedIcon: Icons.local_offer,
        label: l10n.promoCodesTab,
        builder: const AdminPromoPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.monthlyLeaderboard,
        icon: Icons.emoji_events_outlined,
        selectedIcon: Icons.emoji_events,
        label: l10n.monthlyLeaderboardTab,
        builder: const AdminLeaderboardPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.earnings,
        icon: Icons.card_giftcard_outlined,
        selectedIcon: Icons.card_giftcard,
        label: l10n.driverBonusesTab,
        builder: const AdminBonusesPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.earnings,
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        label: l10n.earningsTab,
        builder: const AdminEarningsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.wallet,
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet,
        label: l10n.localeName.startsWith('ar') ? 'المحفظة' : 'Wallet',
        builder: const AdminWalletPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.rewards,
        icon: Icons.emoji_events_outlined,
        selectedIcon: Icons.emoji_events,
        label: isAr ? 'المكافآت' : 'Rewards',
        builder: const AdminRewardsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.businessPartners,
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        label: isAr ? 'شركاء الأعمال' : 'Business Partners',
        builder: const AdminBusinessPartnersPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.driverReviews,
        icon: Icons.star_outline,
        selectedIcon: Icons.star,
        label: l10n.driverReviewsTab,
        builder: const AdminDriverRatingsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.supportInbox,
        icon: Icons.support_agent_outlined,
        selectedIcon: Icons.support_agent,
        label: l10n.supportInboxTab,
        builder: const AdminSupportPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.complaints,
        icon: Icons.report_problem_outlined,
        selectedIcon: Icons.report_problem,
        label: isAr ? 'الشكاوى' : 'Complaints',
        builder: const AdminComplaintsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.notifications,
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: isAr ? 'الإشعارات' : 'Notifications',
        builder: const AdminNotificationsCenterPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.driverPerformance,
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        label: isAr ? 'أداء السائقين' : 'Driver Performance',
        builder: const AdminDriverPerformancePanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.reports,
        icon: Icons.summarize_outlined,
        selectedIcon: Icons.summarize,
        label: isAr ? 'التقارير' : 'Reports',
        builder: const AdminReportsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.auditLog,
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        label: isAr ? 'سجل التدقيق' : 'Audit Log',
        builder: const AdminAuditLogPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.appSettings,
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: isAr ? 'إعدادات التطبيق' : 'App Settings',
        builder: const AdminAppSettingsPanel(),
      ),
      _AdminTabDefinition(
        permission: AdminPermissions.manageAssistants,
        icon: Icons.admin_panel_settings_outlined,
        selectedIcon: Icons.admin_panel_settings,
        label: l10n.assistantsTab,
        builder: const AdminAssistantsPanel(),
      ),
    ];

    return allTabs
        .where((tab) => widget.adminUser.hasAdminPermission(tab.permission))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
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
    final body = tabs[safeIndex].builder;

    final destinations = tabs
        .map(
          (tab) => NavigationRailDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: Text(tab.label),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: isWide
            ? Row(
                children: [
                  Text(l10n.adminPanelTitle),
                  const SizedBox(width: 16),
                  const Expanded(child: AdminGlobalSearchField()),
                ],
              )
            : Text(l10n.adminPanelTitle),
        actions: [
          if (!isWide) const AdminGlobalSearchField(compact: true),
          if (widget.adminUser.hasAdminPermission(AdminPermissions.rideHistory)) ...[
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
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AdminSideNavigation(
                    selectedIndex: safeIndex,
                    destinations: destinations,
                    onSelected: (index) => setState(() => _selectedIndex = index),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              destinations: tabs
                  .map(
                    (tab) => NavigationDestination(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _AdminSideNavigation extends StatelessWidget {
  const _AdminSideNavigation({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavigationRailDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 220,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            final destination = destinations[index];
            final selected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                selected: selected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: selected
                    ? destination.selectedIcon
                    : destination.icon,
                title: destination.label,
                onTap: () => onSelected(index),
              ),
            );
          },
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;

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
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );

        if (drivers.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: AdminFilterBar(
                  value: _filters,
                  onChanged: (v) => setState(() => _filters = v),
                  fields: const [
                    AdminFilterField.province,
                    AdminFilterField.district,
                    AdminFilterField.subDistrict,
                    AdminFilterField.dateRange,
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
                        Text(l10n.noPendingDrivers, textAlign: TextAlign.center),
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
              return AdminFilterBar(
                value: _filters,
                onChanged: (v) => setState(() => _filters = v),
                fields: const [
                  AdminFilterField.province,
                  AdminFilterField.district,
                  AdminFilterField.subDistrict,
                  AdminFilterField.dateRange,
                ],
              );
            }
            return AdminDriverCard(driver: drivers[index - 1]);
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
