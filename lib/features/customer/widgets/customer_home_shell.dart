import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/features/customer/screens/customer_home_map_screen.dart';
import 'package:hilla_ride/features/customer/screens/marketplace_home_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

/// Customer home with Ride + Marketplace tabs (marketplace is fully live/synced).
class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key, required this.user});

  final AppUser user;

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context)!.localeName.startsWith('ar');
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              CustomerHomeMapScreen(user: widget.user),
              MarketplaceHomeScreen(user: widget.user),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: AppBrandAssets.brandBorder),
            ),
            boxShadow: [
              BoxShadow(
                color: AppBrandAssets.brandNavy.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.local_taxi_outlined),
                  selectedIcon: const Icon(Icons.local_taxi),
                  label: isAr ? 'رحلة' : 'Ride',
                ),
                NavigationDestination(
                  icon: const Icon(Icons.storefront_outlined),
                  selectedIcon: const Icon(Icons.storefront),
                  label: isAr ? 'متاجر' : 'Stores',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
