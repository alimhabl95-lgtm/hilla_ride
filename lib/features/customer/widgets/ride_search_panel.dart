import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
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
    final hasDistrict = districtId.trim().isNotEmpty;
    final hasArea = subDistrictId != null && subDistrictId!.trim().isNotEmpty;
    if (hasDistrict && hasArea) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasDistrict
              ? l10n.selectSubDistrictRequired
              : (l10n.localeName.startsWith('ar')
                  ? 'يرجى اختيار القضاء والناحية أولاً.'
                  : 'Please select district and area first.'),
        ),
      ),
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
        destination: destination,
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppBrandAssets.brandBorder),
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
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
    required this.destination,
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
  final PlaceResult? destination;
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
    final hasPickup = !pickupLoading && pickup != null;
    final hasDestination = destination != null;
    final destinationText = destinationLabel?.trim();
    final canBook = hasPickup && hasDestination;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHandle(),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.bookRideTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppBrandAssets.brandNavy,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (customerOnly)
            _CustomerRegionFields(
              districtId: districtId,
              subDistrictId: subDistrictId,
              isArabic: isArabic,
              onDistrictChanged: onDistrictChanged,
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
          const SizedBox(height: 14),
          _TripSearchField(
            onTap: onOpenPickupSearch,
            theme: theme,
            text: pickupLoading
                ? l10n.locatingCurrentPosition
                : (pickupLabel ?? l10n.pickup),
            emphasized: hasPickup,
            leading: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: MapMarkerColors.pickup,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.trip_origin, size: 14, color: Colors.white),
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
          const SizedBox(height: 12),
          _TripSearchField(
            onTap: onOpenDestinationSearch,
            theme: theme,
            text: hasDestination
                ? (destinationText ?? destination!.label)
                : l10n.whereTo,
            emphasized: hasDestination,
            leading: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MapMarkerColors.destination,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.search, size: 14, color: Colors.white),
            ),
            trailing: _MiniAction(
              tooltip: l10n.pinOnMap,
              icon: Icons.edit_location_alt_outlined,
              onPressed: onPinDestination,
            ),
          ),
          const SizedBox(height: 12),
          SavedPlacesBar(
            compact: true,
            onPlaceSelected: onSavedPlaceSelected,
          ),
          if (onBookRide != null) ...[
            const SizedBox(height: AppSpacing.md),
            Opacity(
              opacity: canBook ? 1 : 0.55,
              child: AppPrimaryButton(
                label: l10n.bookRideButton,
                icon: Icons.local_taxi,
                onPressed: onBookRide,
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

  static const Color pickup = AppBrandAssets.brandGold;
  static const Color destination = AppBrandAssets.brandTeal;
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppBrandAssets.brandSurface,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: emphasized
                  ? AppBrandAssets.brandTeal.withValues(alpha: 0.35)
                  : AppBrandAssets.brandBorder,
            ),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight:
                        emphasized ? FontWeight.w700 : FontWeight.w500,
                    color: emphasized
                        ? AppBrandAssets.brandNavy
                        : AppBrandAssets.brandMuted,
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

/// Cascading Governorate → District → Sub-district selector for the
/// customer booking sheet, backed entirely by [ServiceAreaCatalog] (live
/// Firestore data with a Babil-only seed fallback before the first sync).
/// Selecting a governorate/district never assumes a fixed area — it always
/// re-derives its options from the live catalog, so new areas Admin adds
/// show up automatically without an app update.
class _CustomerRegionFields extends StatefulWidget {
  const _CustomerRegionFields({
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
  State<_CustomerRegionFields> createState() => _CustomerRegionFieldsState();
}

class _CustomerRegionFieldsState extends State<_CustomerRegionFields> {
  late String _provinceId = _resolveProvinceId(widget.districtId);

  String _resolveProvinceId(String districtId) {
    final owning =
        ServiceAreaCatalog.instance.provinceIdForDistrict(districtId);
    if (owning != null && owning.isNotEmpty) return owning;
    final provinces = ServiceAreaCatalog.instance.customerProvinces;
    return provinces.isNotEmpty ? provinces.first.id : 'babil';
  }

  @override
  void didUpdateWidget(_CustomerRegionFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.districtId == widget.districtId) return;
    final owning =
        ServiceAreaCatalog.instance.provinceIdForDistrict(widget.districtId);
    if (owning != null && owning.isNotEmpty && owning != _provinceId) {
      setState(() => _provinceId = owning);
    }
  }

  void _onProvinceChanged(String? provinceId) {
    if (provinceId == null || provinceId == _provinceId) return;
    final districts =
        ServiceAreaCatalog.instance.customerDistrictsForProvince(provinceId);
    setState(() => _provinceId = provinceId);
    // A governorate switch always resets to that governorate's first
    // district; the sub-district itself is reset by the parent screen so the
    // customer must confirm the new area before booking.
    widget.onDistrictChanged(districts.isNotEmpty ? districts.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final catalog = ServiceAreaCatalog.instance;
    final provinces = catalog.customerProvinces;
    final districtsInProvince =
        catalog.customerDistrictsForProvince(_provinceId);
    final district = districtsInProvince.firstWhere(
      (d) => d.id == widget.districtId,
      orElse: () => districtsInProvince.isNotEmpty
          ? districtsInProvince.first
          : BabilRegions.districtById(widget.districtId),
    );
    final provinceValue =
        provinces.any((p) => p.id == _provinceId) ? _provinceId : null;
    final districtValue =
        districtsInProvince.any((d) => d.id == widget.districtId)
            ? widget.districtId
            : (districtsInProvince.isNotEmpty ? districtsInProvince.first.id : null);
    // Keep parent district in sync when catalog/province make current id invalid.
    if (districtValue != null &&
        districtValue != widget.districtId &&
        districtsInProvince.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDistrictChanged(districtValue);
      });
    }

    final subIds = district.subDistricts.map((s) => s.id).toSet();
    final subValue = (widget.subDistrictId != null &&
            subIds.contains(widget.subDistrictId))
        ? widget.subDistrictId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.governorateLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: true,
          value: provinceValue,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: provinces
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    widget.isArabic ? p.nameAr : p.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          // Iraq only has one active governorate today; disable the picker
          // rather than show a dropdown with nothing to switch to.
          onChanged: provinces.length > 1 ? _onProvinceChanged : null,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.districtLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: true,
          value: districtValue,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: districtsInProvince
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(
                    widget.isArabic ? d.nameAr : d.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: widget.onDistrictChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          isExpanded: true,
          isDense: true,
          value: subValue,
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
                    widget.isArabic ? s.nameAr : s.nameEn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: widget.onSubDistrictChanged,
        ),
        if (subValue != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.searchRegionHint(
              widget.isArabic
                  ? district.subDistricts
                      .firstWhere((s) => s.id == subValue)
                      .nameAr
                  : district.subDistricts
                      .firstWhere((s) => s.id == subValue)
                      .nameEn,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppBrandAssets.brandTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        color: AppBrandAssets.brandSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppBrandAssets.brandBorder),
        boxShadow: AppShadows.soft,
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
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppBrandAssets.brandTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: AppBrandAssets.brandTeal.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppBrandAssets.brandTealDark,
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
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppBrandAssets.brandTeal,
              ),
            )
          : Icon(icon, size: 20, color: AppBrandAssets.brandTealDark),
    );
  }
}
