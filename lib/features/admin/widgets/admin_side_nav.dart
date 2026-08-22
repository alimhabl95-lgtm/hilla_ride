import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/features/admin/widgets/admin_chrome.dart';

enum AdminNavGroup {
  home,
  rides,
  users,
  stores,
  serviceAreas,
  finance,
  rewards,
  reports,
  settings,
  support,
}

extension AdminNavGroupX on AdminNavGroup {
  String label(bool isAr) {
    switch (this) {
      case AdminNavGroup.home:
        return isAr ? 'الرئيسية' : 'Home';
      case AdminNavGroup.rides:
        return isAr ? 'الرحلات' : 'Rides';
      case AdminNavGroup.users:
        return isAr ? 'المستخدمون' : 'Users';
      case AdminNavGroup.stores:
        return isAr ? 'المتاجر والشركاء' : 'Stores & Partners';
      case AdminNavGroup.serviceAreas:
        return isAr ? 'مناطق الخدمة' : 'Service Areas';
      case AdminNavGroup.finance:
        return isAr ? 'المال' : 'Finance';
      case AdminNavGroup.rewards:
        return isAr ? 'المكافآت' : 'Rewards';
      case AdminNavGroup.reports:
        return isAr ? 'التقارير' : 'Reports';
      case AdminNavGroup.settings:
        return isAr ? 'الإعدادات' : 'Settings';
      case AdminNavGroup.support:
        return isAr ? 'الدعم' : 'Support';
    }
  }
}

class AdminNavItem {
  const AdminNavItem({
    required this.group,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.builder,
  });

  final AdminNavGroup group;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget builder;
}

/// Dark grouped sidebar for the admin console (RTL-friendly).
class AdminSideNav extends StatelessWidget {
  const AdminSideNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.collapsed = false,
    this.onToggleCollapse,
    this.width = 260,
  });

  final List<AdminNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final grouped = <AdminNavGroup, List<MapEntry<int, AdminNavItem>>>{};
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      grouped.putIfAbsent(item.group, () => []).add(MapEntry(i, item));
    }

    final orderedGroups = AdminNavGroup.values
        .where((g) => grouped.containsKey(g))
        .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: collapsed ? 72 : width,
      color: AdminChrome.sidebarBg,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 8 : 16, 20, collapsed ? 8 : 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppBrandAssets.brandTeal.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    color: AppBrandAssets.brandTeal,
                    size: 22,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'هلو تك تك' : 'Hello Tuk-Tuk',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          isAr ? 'لوحة الإدارة' : 'Admin',
                          style: const TextStyle(
                            color: AdminChrome.sidebarMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              children: [
                for (final group in orderedGroups) ...[
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                      child: Text(
                        group.label(isAr),
                        style: const TextStyle(
                          color: AdminChrome.sidebarMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  for (final entry in grouped[group]!)
                    _NavTile(
                      item: entry.value,
                      selected: entry.key == selectedIndex,
                      collapsed: collapsed,
                      onTap: () => onSelected(entry.key),
                    ),
                ],
              ],
            ),
          ),
          if (onToggleCollapse != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onToggleCollapse,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          collapsed
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                          color: AdminChrome.sidebarMuted,
                        ),
                        if (!collapsed) ...[
                          const SizedBox(width: 6),
                          Text(
                            isAr ? 'طي الشريط' : 'Collapse',
                            style: const TextStyle(
                              color: AdminChrome.sidebarMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppBrandAssets.brandTeal : Colors.transparent;
    final fg = selected ? Colors.white : AdminChrome.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: collapsed ? item.label : '',
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: fg,
                    size: 20,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
