import 'package:flutter/material.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/features/customer/widgets/customer_dashboard_ads_bar.dart';
import 'package:hilla_ride/features/customer/widgets/saved_places_bar.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

/// Android customer booking card matching the confirm-ride mockup.
class AndroidCustomerBookingSheet extends StatelessWidget {
  const AndroidCustomerBookingSheet({
    super.key,
    required this.l10n,
    required this.districtId,
    required this.subDistrictId,
    required this.isArabic,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.pickupLoading,
    required this.pickup,
    required this.destination,
    required this.onDistrictChanged,
    required this.onSubDistrictChanged,
    required this.onOpenPickupSearch,
    required this.onOpenDestinationSearch,
    required this.onPinPickup,
    required this.onUseCurrentLocation,
    required this.onPinDestination,
    required this.onSavedPlaceSelected,
    this.onBookRide,
    this.bookRideLoading = false,
  });

  final AppLocalizations l10n;
  final String districtId;
  final String? subDistrictId;
  final bool isArabic;
  final String? pickupLabel;
  final String? destinationLabel;
  final bool pickupLoading;
  final PlaceResult? pickup;
  final PlaceResult? destination;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?> onSubDistrictChanged;
  final VoidCallback? onOpenPickupSearch;
  final VoidCallback onOpenDestinationSearch;
  final VoidCallback onPinPickup;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPinDestination;
  final ValueChanged<PlaceResult> onSavedPlaceSelected;
  final VoidCallback? onBookRide;
  final bool bookRideLoading;

  static bool get isSupported => isNativeMobileApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPickup = !pickupLoading && pickup != null;
    final hasDestination = destination != null;
    final canBook = hasPickup && hasDestination;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = MediaQuery.sizeOf(context).height * 0.68;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppBrandAssets.brandBorder,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const CustomerDashboardAdsBar(),
                  const SizedBox(height: 12),
                  Text(
                    l10n.confirmRideTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppBrandAssets.brandNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AndroidRegionFields(
                    districtId: districtId,
                    subDistrictId: subDistrictId,
                    isArabic: isArabic,
                    onDistrictChanged: onDistrictChanged,
                    onSubDistrictChanged: onSubDistrictChanged,
                  ),
                  const SizedBox(height: 12),
                  _AndroidLocationBlock(
                    label: l10n.pickup,
                    value: pickupLoading
                        ? l10n.locatingCurrentPosition
                        : pickupLabel,
                    hint: l10n.searchPickupHint,
                    loading: pickupLoading,
                    filled: hasPickup,
                    markerColor: const Color(0xFF22C55E),
                    onSearch: pickupLoading ? null : onOpenPickupSearch,
                    onPinOnMap: pickupLoading ? null : onPinPickup,
                    pinLabel: l10n.pinOnMap,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed:
                          pickupLoading ? null : onUseCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: Text(l10n.useMyLocationButton),
                      style: TextButton.styleFrom(
                        foregroundColor: AppBrandAssets.brandTealDark,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ),
                  _AndroidLocationBlock(
                    label: l10n.destination,
                    value: destinationLabel,
                    hint: l10n.searchDestinationHint,
                    loading: false,
                    filled: hasDestination,
                    markerColor: const Color(0xFFEF4444),
                    onSearch: onOpenDestinationSearch,
                    onPinOnMap: onPinDestination,
                    pinLabel: l10n.pinOnMap,
                  ),
                  const SizedBox(height: 10),
                  SavedPlacesBar(
                    compact: true,
                    onPlaceSelected: onSavedPlaceSelected,
                  ),
                  if (onBookRide != null) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed:
                          canBook && !bookRideLoading ? onBookRide : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppBrandAssets.brandTeal,
                        disabledBackgroundColor:
                            AppBrandAssets.brandTeal.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: bookRideLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.bookRideConfirmButton,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AndroidLocationBlock extends StatelessWidget {
  const _AndroidLocationBlock({
    required this.label,
    required this.value,
    required this.hint,
    required this.loading,
    required this.filled,
    required this.markerColor,
    required this.onSearch,
    required this.onPinOnMap,
    required this.pinLabel,
  });

  final String label;
  final String? value;
  final String hint;
  final bool loading;
  final bool filled;
  final Color markerColor;
  final VoidCallback? onSearch;
  final VoidCallback? onPinOnMap;
  final String pinLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = value?.trim();
    final display = (trimmed != null && trimmed.isNotEmpty) ? trimmed : hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onSearch,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppBrandAssets.brandNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        display,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: filled
                              ? AppBrandAssets.brandNavy
                              : AppBrandAssets.brandMuted,
                          fontWeight:
                              filled ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: markerColor, width: 6),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onPinOnMap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppBrandAssets.brandTeal.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppBrandAssets.brandTealDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  pinLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppBrandAssets.brandTealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AndroidRegionFields extends StatefulWidget {
  const _AndroidRegionFields({
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
  State<_AndroidRegionFields> createState() => _AndroidRegionFieldsState();
}

class _AndroidRegionFieldsState extends State<_AndroidRegionFields> {
  late String _provinceId = _resolveProvinceId(widget.districtId);

  String _resolveProvinceId(String districtId) {
    final owning =
        ServiceAreaCatalog.instance.provinceIdForDistrict(districtId);
    if (owning != null && owning.isNotEmpty) return owning;
    final provinces = ServiceAreaCatalog.instance.customerProvinces;
    return provinces.isNotEmpty ? provinces.first.id : 'babil';
  }

  @override
  void didUpdateWidget(_AndroidRegionFields oldWidget) {
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
    widget.onDistrictChanged(districts.isNotEmpty ? districts.first.id : null);
  }

  String _effectiveDistrictId(String districtId, String? subDistrictId) {
    if (subDistrictId == null || subDistrictId.isEmpty) return districtId;
    for (final district in BabilRegions.customerDistricts) {
      if (district.subDistricts.any((sub) => sub.id == subDistrictId)) {
        return district.id;
      }
    }
    return districtId;
  }

  List<BabilDistrict> _districtOptions() {
    final effectiveDistrictId =
        _effectiveDistrictId(widget.districtId, widget.subDistrictId);
    var options =
        ServiceAreaCatalog.instance.customerDistrictsForProvince(_provinceId);
    if (options.isEmpty) {
      options = BabilRegions.customerDistricts;
    }
    if (!options.any((district) => district.id == effectiveDistrictId)) {
      options = [
        BabilRegions.districtById(effectiveDistrictId),
        ...options.where((district) => district.id != effectiveDistrictId),
      ];
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ServiceAreaCatalog.instance;
    final provinces = catalog.customerProvinces;
    final effectiveDistrictId =
        _effectiveDistrictId(widget.districtId, widget.subDistrictId);
    final districtsInProvince = _districtOptions();
    final district = districtsInProvince.firstWhere(
      (d) => d.id == effectiveDistrictId,
      orElse: () => BabilRegions.districtById(effectiveDistrictId),
    );
    final provinceValue =
        provinces.any((p) => p.id == _provinceId) ? _provinceId : null;
    final districtValue = districtsInProvince.any((d) => d.id == effectiveDistrictId)
        ? effectiveDistrictId
        : (districtsInProvince.isNotEmpty ? districtsInProvince.first.id : null);
    final subIds = district.subDistricts.map((s) => s.id).toSet();
    final subValue = (widget.subDistrictId != null &&
            subIds.contains(widget.subDistrictId))
        ? widget.subDistrictId
        : null;

    return Column(
      children: [
        _SelectRow(
          label: l10n.yourCityLabel,
          value: provinceValue,
          hint: l10n.governorateLabel,
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
          onChanged: provinces.length > 1 ? _onProvinceChanged : null,
        ),
        const SizedBox(height: 10),
        _SelectRow(
          label: l10n.districtLabel,
          value: districtValue,
          hint: l10n.districtLabel,
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
        _SelectRow(
          label: l10n.areaLabel,
          value: subValue,
          hint: l10n.selectSubDistrictHint,
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
      ],
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: AppBrandAssets.brandTeal,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppBrandAssets.brandMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                hint: Text(
                  hint,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppBrandAssets.brandMuted,
                  ),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppBrandAssets.brandTeal,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
