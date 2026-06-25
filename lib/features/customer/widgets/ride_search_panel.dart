import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/features/customer/screens/place_search_screen.dart';
import 'package:hilla_ride/features/customer/widgets/saved_places_bar.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

class RideSearchPanel extends StatelessWidget {
  const RideSearchPanel({
    super.key,
    required this.regionExpanded,
    required this.districtId,
    required this.subDistrictId,
    required this.isArabic,
    required this.region,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.pickupLoading,
    required this.pickup,
    required this.destination,
    required this.onToggleRegion,
    required this.onDistrictChanged,
    required this.onSubDistrictChanged,
    required this.onPickupSelected,
    required this.onDestinationSelected,
    required this.onPinPickup,
    required this.onUseCurrentLocation,
    required this.onPinDestination,
    required this.onSavedPlaceSelected,
    this.customerOnly = false,
    this.bottomSheetStyle = false,
    this.regionSelectorOnly = false,
    this.onBookRide,
  });

  final bool regionExpanded;
  final String districtId;
  final String? subDistrictId;
  final bool isArabic;
  final bool customerOnly;
  final bool bottomSheetStyle;
  final bool regionSelectorOnly;
  final RegionSearchContext region;
  final String? pickupLabel;
  final String? destinationLabel;
  final bool pickupLoading;
  final PlaceResult? pickup;
  final PlaceResult? destination;
  final VoidCallback onToggleRegion;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onSubDistrictChanged;
  final ValueChanged<PlaceResult> onPickupSelected;
  final ValueChanged<PlaceResult> onDestinationSelected;
  final VoidCallback onPinPickup;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPinDestination;
  final ValueChanged<PlaceResult> onSavedPlaceSelected;
  final VoidCallback? onBookRide;

  Future<void> _openSearch(
    BuildContext context, {
    required String title,
    required String hint,
    required String? initialQuery,
    required ValueChanged<PlaceResult> onSelected,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await Navigator.of(context, rootNavigator: true).push<PlaceResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PlaceSearchScreen(
          title: title,
          hint: hint,
          initialQuery: initialQuery ?? '',
          region: region,
        ),
      ),
    );

    if (result != null) {
      onSelected(result);
    }
  }

  bool _ensureSubDistrictSelected(BuildContext context, AppLocalizations l10n) {
    if (subDistrictId != null && subDistrictId!.trim().isNotEmpty) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.selectSubDistrictRequired)),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (regionSelectorOnly) {
      return _RegionDropdowns(
        districtId: districtId,
        subDistrictId: subDistrictId,
        isArabic: isArabic,
        onDistrictChanged: onDistrictChanged,
        onSubDistrictChanged: onSubDistrictChanged,
      );
    }

    if (bottomSheetStyle) {
      return _BottomSheetSearch(
        l10n: l10n,
        districtId: districtId,
        subDistrictId: subDistrictId,
        isArabic: isArabic,
        customerOnly: customerOnly,
        pickupLabel: pickupLabel,
        destinationLabel: destinationLabel,
        pickupLoading: pickupLoading,
        pickup: pickup,
        onDistrictChanged: onDistrictChanged,
        onSubDistrictChanged: onSubDistrictChanged,
        onOpenDestinationSearch: () {
          if (!_ensureSubDistrictSelected(context, l10n)) return;
          _openSearch(
            context,
            title: l10n.whereTo,
            hint: l10n.searchPlaces,
            initialQuery: destinationLabel,
            onSelected: onDestinationSelected,
          );
        },
        onOpenPickupSearch: pickupLoading
            ? null
            : () {
                if (!_ensureSubDistrictSelected(context, l10n)) return;
                _openSearch(
                  context,
                  title: l10n.pickup,
                  hint: l10n.searchPlaces,
                  initialQuery: pickupLabel,
                  onSelected: onPickupSelected,
                );
              },
        onPinPickup: () {
          if (!_ensureSubDistrictSelected(context, l10n)) return;
          onPinPickup();
        },
        onUseCurrentLocation: () {
          if (!_ensureSubDistrictSelected(context, l10n)) return;
          onUseCurrentLocation();
        },
        onPinDestination: () {
          if (!_ensureSubDistrictSelected(context, l10n)) return;
          onPinDestination();
        },
        onSavedPlaceSelected: (place) {
          if (!_ensureSubDistrictSelected(context, l10n)) return;
          onSavedPlaceSelected(place);
        },
        onBookRide: onBookRide == null
            ? null
            : () {
                if (!_ensureSubDistrictSelected(context, l10n)) return;
                onBookRide!();
              },
      );
    }

    final theme = Theme.of(context);

    return Material(
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RegionChip(
              expanded: regionExpanded,
              districtId: districtId,
              subDistrictId: subDistrictId,
              isArabic: isArabic,
              customerOnly: customerOnly,
              onToggle: onToggleRegion,
              onDistrictChanged: onDistrictChanged,
              onSubDistrictChanged: onSubDistrictChanged,
            ),
            const SizedBox(height: 10),
            _LocationFields(
              l10n: l10n,
              theme: theme,
              pickupLabel: pickupLabel,
              destinationLabel: destinationLabel,
              pickupLoading: pickupLoading,
              pickup: pickup,
              onOpenPickupSearch: pickupLoading
                  ? null
                  : () => _openSearch(
                        context,
                        title: l10n.pickup,
                        hint: l10n.searchPlaces,
                        initialQuery: pickupLabel,
                        onSelected: onPickupSelected,
                      ),
              onOpenDestinationSearch: () => _openSearch(
                context,
                title: l10n.whereTo,
                hint: l10n.searchPlaces,
                initialQuery: destinationLabel,
                onSelected: onDestinationSelected,
              ),
              onPinPickup: onPinPickup,
              onUseCurrentLocation: onUseCurrentLocation,
              onPinDestination: onPinDestination,
            ),
            const SizedBox(height: 8),
            SavedPlacesBar(
              compact: true,
              onPlaceSelected: onSavedPlaceSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetSearch extends StatelessWidget {
  const _BottomSheetSearch({
    required this.l10n,
    required this.districtId,
    required this.subDistrictId,
    required this.isArabic,
    required this.customerOnly,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.pickupLoading,
    required this.pickup,
    required this.onDistrictChanged,
    required this.onSubDistrictChanged,
    required this.onOpenDestinationSearch,
    required this.onOpenPickupSearch,
    required this.onPinPickup,
    required this.onUseCurrentLocation,
    required this.onPinDestination,
    required this.onSavedPlaceSelected,
    this.onBookRide,
  });

  final AppLocalizations l10n;
  final String districtId;
  final String? subDistrictId;
  final bool isArabic;
  final bool customerOnly;
  final String? pickupLabel;
  final String? destinationLabel;
  final bool pickupLoading;
  final PlaceResult? pickup;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onSubDistrictChanged;
  final VoidCallback onOpenDestinationSearch;
  final VoidCallback? onOpenPickupSearch;
  final VoidCallback onPinPickup;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPinDestination;
  final ValueChanged<PlaceResult> onSavedPlaceSelected;
  final VoidCallback? onBookRide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinationText = destinationLabel?.trim();
    final hasDestination =
        destinationText != null && destinationText.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (customerOnly)
            _CustomerRegionFields(
              districtId: districtId,
              subDistrictId: subDistrictId,
              isArabic: isArabic,
              onSubDistrictChanged: onSubDistrictChanged,
            )
          else
            _RegionDropdowns(
              districtId: districtId,
              subDistrictId: subDistrictId,
              isArabic: isArabic,
              onDistrictChanged: onDistrictChanged,
              onSubDistrictChanged: onSubDistrictChanged,
            ),
          const SizedBox(height: 12),
          _TripSearchField(
            onTap: onOpenPickupSearch,
            theme: theme,
            text: pickupLoading
                ? l10n.locatingCurrentPosition
                : (pickupLabel ?? l10n.pickup),
            emphasized: !pickupLoading &&
                pickupLabel != null &&
                pickupLabel!.trim().isNotEmpty,
            leading: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: MapMarkerColors.pickup,
                shape: BoxShape.circle,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniAction(
                  tooltip: l10n.pinOnMap,
                  icon: Icons.edit_location_alt_outlined,
                  onPressed: pickupLoading ? null : onPinPickup,
                ),
                _MiniAction(
                  tooltip: l10n.currentLocation,
                  icon: Icons.my_location,
                  loading: pickupLoading,
                  onPressed: pickupLoading ? null : onUseCurrentLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _TripSearchField(
            onTap: onOpenDestinationSearch,
            theme: theme,
            text: hasDestination ? destinationText : l10n.whereTo,
            emphasized: hasDestination,
            leading: Icon(
              Icons.search,
              color: theme.colorScheme.outline,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniAction(
                  tooltip: l10n.pinOnMap,
                  icon: Icons.edit_location_alt_outlined,
                  onPressed: onPinDestination,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: MapMarkerColors.destination,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SavedPlacesBar(
            compact: true,
            onPlaceSelected: onSavedPlaceSelected,
          ),
          if (onBookRide != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onBookRide,
              icon: const Icon(Icons.local_taxi),
              label: Text(l10n.bookRideButton),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MapMarkerColors {
  MapMarkerColors._();

  static const Color pickup = Color(0xFFFF9500);
  static const Color destination = Color(0xFF007AFF);
}

class _TripSearchField extends StatelessWidget {
  const _TripSearchField({
    required this.onTap,
    required this.theme,
    required this.text,
    required this.leading,
    required this.trailing,
    this.emphasized = false,
  });

  final VoidCallback? onTap;
  final ThemeData theme;
  final String text;
  final Widget leading;
  final Widget trailing;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight:
                        emphasized ? FontWeight.w600 : FontWeight.w500,
                    color: emphasized
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerRegionFields extends StatelessWidget {
  const _CustomerRegionFields({
    required this.districtId,
    required this.subDistrictId,
    required this.isArabic,
    required this.onSubDistrictChanged,
  });

  final String districtId;
  final String? subDistrictId;
  final bool isArabic;
  final ValueChanged<String?> onSubDistrictChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final district = BabilRegions.districtById(districtId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.districtLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isArabic ? district.nameAr : district.nameEn,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: true,
          value: subDistrictId,
          decoration: InputDecoration(
            labelText: l10n.subDistrictLabel,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          hint: Text(l10n.selectSubDistrictHint),
          items: district.subDistricts
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    isArabic ? s.nameAr : s.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onSubDistrictChanged,
        ),
      ],
    );
  }
}

class _RegionDropdowns extends StatelessWidget {
  const _RegionDropdowns({
    required this.districtId,
    required this.subDistrictId,
    required this.isArabic,
    required this.onDistrictChanged,
    required this.onSubDistrictChanged,
  });

  final String districtId;
  final String? subDistrictId;
  final bool isArabic;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onSubDistrictChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final district = BabilRegions.districtById(districtId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: true,
          value: districtId,
          decoration: InputDecoration(
            labelText: l10n.districtLabel,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: BabilRegions.districts
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    isArabic ? d.nameAr : d.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onDistrictChanged,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: true,
          value: subDistrictId,
          decoration: InputDecoration(
            labelText: l10n.subDistrictLabel,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: district.subDistricts
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    isArabic ? s.nameAr : s.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onSubDistrictChanged,
        ),
      ],
    );
  }
}

class _LocationFields extends StatelessWidget {
  const _LocationFields({
    required this.l10n,
    required this.theme,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.pickupLoading,
    required this.pickup,
    required this.onOpenPickupSearch,
    required this.onOpenDestinationSearch,
    required this.onPinPickup,
    required this.onUseCurrentLocation,
    required this.onPinDestination,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final String? pickupLabel;
  final String? destinationLabel;
  final bool pickupLoading;
  final PlaceResult? pickup;
  final VoidCallback? onOpenPickupSearch;
  final VoidCallback onOpenDestinationSearch;
  final VoidCallback onPinPickup;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPinDestination;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          _LocationRow(
            icon: Icons.circle,
            iconColor: MapMarkerColors.pickup,
            iconSize: 12,
            showConnector: true,
            label: l10n.pickup,
            value: pickupLoading ? l10n.locatingCurrentPosition : pickupLabel,
            hint: l10n.searchPlaces,
            loading: pickupLoading,
            onTap: onOpenPickupSearch,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniAction(
                  tooltip: l10n.pinOnMap,
                  icon: Icons.edit_location_alt_outlined,
                  onPressed: pickupLoading ? null : onPinPickup,
                ),
                _MiniAction(
                  tooltip: l10n.currentLocation,
                  icon: Icons.my_location,
                  loading: pickupLoading,
                  onPressed: pickupLoading ? null : onUseCurrentLocation,
                ),
                SavePlaceButton(
                  place: pickupLoading ? null : pickup,
                  compact: true,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          _LocationRow(
            icon: Icons.square_rounded,
            iconColor: MapMarkerColors.destination,
            iconSize: 14,
            showConnector: false,
            label: l10n.whereTo,
            value: destinationLabel,
            hint: l10n.searchPlaces,
            emphasized: true,
            onTap: onOpenDestinationSearch,
            trailing: _MiniAction(
              tooltip: l10n.pinOnMap,
              icon: Icons.edit_location_alt_outlined,
              onPressed: onPinDestination,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    required this.expanded,
    required this.districtId,
    required this.subDistrictId,
    required this.isArabic,
    required this.onToggle,
    required this.onDistrictChanged,
    required this.onSubDistrictChanged,
    this.customerOnly = false,
  });

  final bool expanded;
  final String districtId;
  final String? subDistrictId;
  final bool isArabic;
  final bool customerOnly;
  final VoidCallback onToggle;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onSubDistrictChanged;

  @override
  Widget build(BuildContext context) {
    final district = BabilRegions.districtById(districtId);
    final sub = subDistrictId == null
        ? null
        : BabilRegions.subDistrictById(districtId, subDistrictId!);
    final regionLabel = sub == null
        ? (isArabic ? district.nameAr : district.nameEn)
        : '${isArabic ? district.nameAr : district.nameEn} • ${isArabic ? sub.nameAr : sub.nameEn}';

    if (!expanded) {
      return InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(
                Icons.place_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  regionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Icon(
                Icons.expand_more,
                size: 18,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
        ),
      );
    }

    return _RegionDropdowns(
      districtId: districtId,
      subDistrictId: subDistrictId,
      isArabic: isArabic,
      onDistrictChanged: onDistrictChanged,
      onSubDistrictChanged: onSubDistrictChanged,
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.showConnector,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.loading = false,
    this.emphasized = false,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final bool showConnector;
  final String label;
  final String? value;
  final String hint;
  final VoidCallback? onTap;
  final bool loading;
  final bool emphasized;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = value?.trim();
    final hasValue = trimmed != null && trimmed.isNotEmpty;
    final displayText = hasValue ? trimmed : hint;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  Icon(icon, size: iconSize, color: iconColor),
                  if (showConnector)
                    Container(
                      width: 2,
                      height: 28,
                      margin: const EdgeInsets.only(top: 4),
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 2),
                  loading
                      ? Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          displayText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                emphasized ? FontWeight.w600 : FontWeight.w500,
                            color: hasValue
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outline,
                          ),
                        ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      onPressed: onPressed,
      icon: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : Icon(icon, size: 18),
    );
  }
}
