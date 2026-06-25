import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
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
import 'package:hilla_ride/features/admin/widgets/admin_broadcast_actions.dart';
import 'package:hilla_ride/features/admin/widgets/admin_fake_driver_controls.dart';
import 'package:hilla_ride/features/admin/widgets/admin_profile_button.dart';
import 'package:hilla_ride/features/admin/widgets/admin_driver_card.dart';
import 'package:hilla_ride/features/admin/widgets/admin_live_map_panel.dart';
import 'package:hilla_ride/features/admin/screens/admin_ride_detail_screen.dart';
import 'package:hilla_ride/features/admin/screens/admin_ride_status_screen.dart';
import 'package:hilla_ride/features/admin/widgets/admin_ride_promo_summary.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
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

  List<_AdminTabDefinition> _tabs(AppLocalizations l10n) {
    final allTabs = <_AdminTabDefinition>[
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
        title: Text(l10n.adminPanelTitle),
        actions: [
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

class _PendingDriversPanel extends StatelessWidget {
  const _PendingDriversPanel();

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
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );

        if (drivers.isEmpty) {
          return Center(
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
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: drivers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              AdminDriverCard(driver: drivers[index]),
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
  String? _cityFilterId;
  String? _subDistrictFilterId;

  String _districtLabel(BabilDistrict district, String localeName) {
    return localeName.startsWith('ar') ? district.nameAr : district.nameEn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    final selectedDistrict = _cityFilterId == null
        ? null
        : BabilRegions.districtById(_cityFilterId!);

    return StreamBuilder<List<Ride>>(
      stream: adminService.watchActiveRides(),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? const [];
        final filtered = rides.where((ride) {
          if (_cityFilterId != null && ride.districtId != _cityFilterId) {
            return false;
          }
          if (_subDistrictFilterId != null &&
              ride.subDistrictId != _subDistrictFilterId) {
            return false;
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
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
                    onChanged: (value) {
                      setState(() {
                        _cityFilterId = value;
                        _subDistrictFilterId = null;
                      });
                    },
                  ),
                  if (selectedDistrict != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _subDistrictFilterId,
                      decoration: InputDecoration(
                        labelText: l10n.filterBySubDistrict,
                        prefixIcon: const Icon(Icons.place_outlined),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allSubDistricts),
                        ),
                        for (final sub in selectedDistrict.subDistricts)
                          DropdownMenuItem<String?>(
                            value: sub.id,
                            child: Text(
                              l10n.localeName.startsWith('ar')
                                  ? sub.nameAr
                                  : sub.nameEn,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _subDistrictFilterId = value),
                    ),
                  ],
                ],
              ),
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

class _AllDriversPanel extends StatelessWidget {
  const _AllDriversPanel({required this.adminUser});

  final AppUser adminUser;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    final isManager = adminUser.isOwnerManager;

    return StreamBuilder<List<DriverProfile>>(
      stream: adminService.watchAllDrivers(),
      builder: (context, snapshot) {
        final drivers = List<DriverProfile>.from(snapshot.data ?? const [])
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: drivers.isEmpty ? 1 : drivers.length + 1,
          separatorBuilder: (_, index) {
            if (index == 0) return const SizedBox(height: 12);
            return const SizedBox(height: 12);
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return AdminFakeDriverBar(isManager: isManager);
            }
            if (drivers.isEmpty) {
              return Center(child: Text(l10n.noDriversYet));
            }
            final driver = drivers[index - 1];
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
  String? _cityFilterId;
  String? _subDistrictFilterId;

  String _districtLabel(BabilDistrict district, String localeName) {
    return localeName.startsWith('ar') ? district.nameAr : district.nameEn;
  }

  String _subDistrictLabel(
    String districtId,
    String subDistrictId,
    String localeName,
  ) {
    final sub = BabilRegions.subDistrictById(districtId, subDistrictId);
    return localeName.startsWith('ar') ? sub.nameAr : sub.nameEn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    const fareService = FareService();
    final selectedDistrict = _cityFilterId == null
        ? null
        : BabilRegions.districtById(_cityFilterId!);

    return StreamBuilder<List<Ride>>(
      stream: adminService.watchRecentRides(),
      builder: (context, snapshot) {
        final rides = snapshot.data ?? const [];
        final filtered = rides.where((ride) {
          if (_cityFilterId != null && ride.districtId != _cityFilterId) {
            return false;
          }
          if (_subDistrictFilterId != null &&
              ride.subDistrictId != _subDistrictFilterId) {
            return false;
          }
          return true;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
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
                    onChanged: (value) {
                      setState(() {
                        _cityFilterId = value;
                        _subDistrictFilterId = null;
                      });
                    },
                  ),
                  if (selectedDistrict != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _subDistrictFilterId,
                      decoration: InputDecoration(
                        labelText: l10n.filterBySubDistrict,
                        prefixIcon: const Icon(Icons.place_outlined),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allSubDistricts),
                        ),
                        for (final sub in selectedDistrict.subDistricts)
                          DropdownMenuItem<String?>(
                            value: sub.id,
                            child: Text(
                              l10n.localeName.startsWith('ar')
                                  ? sub.nameAr
                                  : sub.nameEn,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _subDistrictFilterId = value),
                    ),
                  ],
                ],
              ),
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
                        final district = ride.districtId.isEmpty
                            ? null
                            : BabilRegions.districtById(ride.districtId);
                        final cityLabel = district == null
                            ? ''
                            : _districtLabel(district, l10n.localeName);
                        final subLabel = ride.districtId.isEmpty ||
                                ride.subDistrictId.isEmpty
                            ? ''
                            : _subDistrictLabel(
                                ride.districtId,
                                ride.subDistrictId,
                                l10n.localeName,
                              );

                        return ListTile(
                          title: Text(
                            '${ride.pickupLabel} → ${ride.destinationLabel}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                          isThreeLine: ride.usedPromo,
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
    final district = ride.districtId.isEmpty
        ? null
        : BabilRegions.districtById(ride.districtId);
    final cityLabel = district == null
        ? ''
        : (localeName.startsWith('ar') ? district.nameAr : district.nameEn);
    final subLabel = ride.districtId.isEmpty || ride.subDistrictId.isEmpty
        ? ''
        : (() {
            final sub = BabilRegions.subDistrictById(
              ride.districtId,
              ride.subDistrictId,
            );
            return localeName.startsWith('ar') ? sub.nameAr : sub.nameEn;
          })();

    return Card(
      child: ListTile(
        title: Text('${ride.pickupLabel} → ${ride.destinationLabel}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
