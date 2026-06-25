import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/map_camera_helper.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/features/customer/screens/book_ride_screen.dart';
import 'package:hilla_ride/features/customer/screens/google_map_pin_picker_screen.dart';
import 'package:hilla_ride/features/customer/widgets/ride_search_panel.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

class CustomerHomeMapScreen extends StatefulWidget {
  const CustomerHomeMapScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CustomerHomeMapScreen> createState() => _CustomerHomeMapScreenState();
}

class _CustomerHomeMapScreenState extends State<CustomerHomeMapScreen> {
  GoogleMapController? _mapController;
  PlaceResult? _pickup;
  PlaceResult? _destination;
  final String _districtId = BabilRegions.customerDistrictId;
  String? _subDistrictId;
  var _pickupLoading = false;
  var _markersReady = false;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;

  @override
  void initState() {
    super.initState();
    MapMarkerIcons.ensureLoaded().then((_) {
      if (mounted) setState(() => _markersReady = true);
      _refreshTripMarkers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().pricingService.prefetchConfig(
            districtId: _districtId,
          );
    });
  }

  RegionSearchContext get _region => RegionSearchContext(
        districtId: _districtId,
        subDistrictId: _subDistrictId,
      );

  Future<void> _refreshTripMarkers() async {
    if (!_markersReady || !mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final pickupIcon =
        await MapMarkerIcons.tripMarker(isPickup: true, label: l10n.pickup);

    BitmapDescriptor? destinationIcon = _destinationMarkerIcon;
    if (_destination != null) {
      destinationIcon = await MapMarkerIcons.tripMarker(
        isPickup: false,
        label: _destination!.label,
      );
    } else {
      destinationIcon = null;
    }

    if (!mounted) return;
    setState(() {
      _pickupMarkerIcon = pickupIcon;
      _destinationMarkerIcon = destinationIcon;
    });
  }

  void _clearDestinationIfOutsideRegion() {
    final destination = _destination;
    if (destination == null) return;
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isWithinRegion(
      _region,
      ll.LatLng(destination.latitude, destination.longitude),
    )) {
      setState(() => _destination = null);
    }
  }

  void _clearPickupIfOutsideRegion() {
    final pickup = _pickup;
    if (pickup == null) return;
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isWithinRegion(
      _region,
      ll.LatLng(pickup.latitude, pickup.longitude),
    )) {
      setState(() => _pickup = null);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (_subDistrictId == null || _subDistrictId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectSubDistrictRequired)),
      );
      return;
    }
    setState(() => _pickupLoading = true);

    final geocoding = context.read<AppState>().geocodingService;
    final district = BabilRegions.customerDistrict;
    final isArabic = l10n.localeName.startsWith('ar');
    final districtName = isArabic ? district.nameAr : district.nameEn;
    ll.LatLng point = _region.searchCenter;
    var usedGps = false;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationServiceDisabled)),
          );
        }
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.locationPermissionDenied)),
            );
          }
        } else if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          ).timeout(const Duration(seconds: 14));
          final candidate = ll.LatLng(position.latitude, position.longitude);
          if (geocoding.isWithinRegion(_region, candidate)) {
            point = candidate;
            usedGps = true;
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.searchOutsideRegion)),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _pickup = PlaceResult(
          label: usedGps
              ? l10n.currentLocation
              : '${l10n.currentLocation} • $districtName',
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
      _moveMap(LatLng(point.latitude, point.longitude));

      final label = await geocoding
          .reverseGeocode(
            point,
            acceptLanguage: Localizations.localeOf(context).languageCode,
            region: _region,
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;

      var displayLabel = label;
      if (RegExp(r'^-?\d+\.\d{4,6},\s*-?\d+\.\d{4,6}$').hasMatch(label.trim())) {
        displayLabel = '${l10n.currentLocation} • $districtName';
      }

      setState(() {
        _pickup = PlaceResult(
          label: usedGps ? displayLabel : '${l10n.currentLocation} • $displayLabel',
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
      unawaited(_refreshTripMarkers());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationFetchFailed)),
        );
        setState(() {
          _pickup ??= PlaceResult(
            label: '${l10n.currentLocation} • $districtName',
            latitude: point.latitude,
            longitude: point.longitude,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _pickupLoading = false);
    }
  }

  void _setPickupFromSearch(PlaceResult place) {
    final l10n = AppLocalizations.of(context)!;
    if (_subDistrictId == null || _subDistrictId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectSubDistrictRequired)),
      );
      return;
    }
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isWithinRegion(
      _region,
      ll.LatLng(place.latitude, place.longitude),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchOutsideRegion)),
      );
      return;
    }
    final destination = _destination;
    if (destination != null &&
        !RideLocationRules.areDistinctPlaces(place, destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
      );
      return;
    }
    setState(() => _pickup = place);
    _moveMap(LatLng(place.latitude, place.longitude));
    _fitTripOnMap();
    unawaited(_refreshTripMarkers());
  }

  bool _applyDestination(PlaceResult place) {
    final l10n = AppLocalizations.of(context)!;
    if (_subDistrictId == null || _subDistrictId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectSubDistrictRequired)),
      );
      return false;
    }
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isWithinRegion(
      _region,
      ll.LatLng(place.latitude, place.longitude),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchOutsideRegion)),
      );
      return false;
    }
    final pickup = _pickup;
    if (pickup != null && !RideLocationRules.areDistinctPlaces(pickup, place)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
      );
      return false;
    }
    setState(() => _destination = place);
    unawaited(_refreshTripMarkers());
    _moveMap(LatLng(place.latitude, place.longitude));
    _fitTripOnMap();
    return true;
  }

  Future<void> _openPinPicker({required bool forPickup}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_subDistrictId == null || _subDistrictId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectSubDistrictRequired)),
      );
      return;
    }
    final initial = forPickup
        ? (_pickup != null
            ? ll.LatLng(_pickup!.latitude, _pickup!.longitude)
            : null)
        : (_destination != null
            ? ll.LatLng(_destination!.latitude, _destination!.longitude)
            : null);

    final result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => GoogleMapPinPickerScreen(
          title: forPickup ? l10n.pickup : l10n.destination,
          region: _region,
          initialPoint: initial,
          isPickup: forPickup,
        ),
      ),
    );

    if (result == null || !mounted) return;
    if (forPickup) {
      _setPickupFromSearch(result);
    } else {
      _applyDestination(result);
    }
  }

  Set<Marker> _buildMarkers() {
    if (!_markersReady) return const {};

    final markers = <Marker>{};
    if (_pickup != null && _pickupMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickup!.latitude, _pickup!.longitude),
          icon: _pickupMarkerIcon!,
          anchor: const Offset(0.5, 0.72),
          zIndexInt: 2,
        ),
      );
    }
    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destination!.latitude, _destination!.longitude),
          icon: _destinationMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
          anchor: const Offset(0.5, 0.72),
          zIndexInt: 2,
        ),
      );
    }
    return markers;
  }

  void _fitTripOnMap() {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[];
    if (_pickup != null) {
      points.add(LatLng(_pickup!.latitude, _pickup!.longitude));
    }
    if (_destination != null) {
      points.add(LatLng(_destination!.latitude, _destination!.longitude));
    }
    if (points.isEmpty) return;

    if (points.length == 1) {
      _moveMap(points.first);
      return;
    }

    unawaited(MapCameraHelper.fitPoints(controller, points));
  }

  void _moveMap(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  void _onSubDistrictChanged(String? id) {
    setState(() => _subDistrictId = id);
    if (id == null || id.isEmpty) return;
    context.read<AppState>().pricingService.prefetchConfig(
          districtId: _districtId,
          subDistrictId: id,
        );
    _clearDestinationIfOutsideRegion();
    _clearPickupIfOutsideRegion();
    unawaited(_refreshTripMarkers());
    final sub = BabilRegions.subDistrictById(_districtId, id);
    _moveMap(LatLng(sub.center.latitude, sub.center.longitude));
    if (_pickup == null) {
      unawaited(_useCurrentLocation());
    }
  }

  Future<void> _openBookRide() async {
    final l10n = AppLocalizations.of(context)!;
    final pickup = _pickup;
    final destination = _destination;
    if (pickup == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationRequired)),
      );
      return;
    }
    if (_subDistrictId == null || _subDistrictId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectSubDistrictRequired)),
      );
      return;
    }
    if (!RideLocationRules.areDistinctPlaces(pickup, destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
      );
      return;
    }

    final resolved = BabilRegions.resolveFromPoint(
      ll.LatLng(pickup.latitude, pickup.longitude),
    );
    if (resolved.districtId != BabilRegions.customerDistrictId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchOutsideRegion)),
      );
      return;
    }

    try {
      final activeRide = await context
          .read<AppState>()
          .rideService
          .fetchActiveRideForCustomer(widget.user.uid);
      if (!mounted) return;
      if (activeRide != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.activeRideExists)),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookRideScreen(
            user: widget.user,
            pickup: pickup,
            destination: destination,
            districtId: _districtId,
            subDistrictId: _subDistrictId!,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fareCalculationFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = l10n.localeName.startsWith('ar');
    final mapCenter = LatLng(
      _region.searchCenter.latitude,
      _region.searchCenter.longitude,
    );
    final pickupLabel = _pickupLoading
        ? l10n.locatingCurrentPosition
        : _pickup?.label;
    final markers = _buildMarkers();

    return Scaffold(
      body: Stack(
        children: [
          GoogleMapView(
            initialPosition: mapCenter,
            zoom: 14,
            onMapCreated: (c) => _mapController = c,
            markers: markers,
          ),
          Positioned(
            right: 16,
            bottom: 340,
            child: SafeArea(
              top: false,
              child: FloatingActionButton.small(
                heroTag: 'customer_my_location',
                onPressed: _pickupLoading ? null : _useCurrentLocation,
                child: _pickupLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 16,
              shadowColor: Colors.black38,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: RideSearchPanel(
                  bottomSheetStyle: true,
                  customerOnly: true,
                  regionExpanded: true,
                  districtId: _districtId,
                  subDistrictId: _subDistrictId,
                  isArabic: isArabic,
                  region: _region,
                  pickupLabel: pickupLabel,
                  destinationLabel: _destination?.label,
                  pickupLoading: _pickupLoading,
                  pickup: _pickup,
                  destination: _destination,
                  onToggleRegion: () {},
                  onDistrictChanged: (_) {},
                  onSubDistrictChanged: _onSubDistrictChanged,
                  onPickupSelected: _setPickupFromSearch,
                  onDestinationSelected: _applyDestination,
                  onPinPickup: () => _openPinPicker(forPickup: true),
                  onUseCurrentLocation: _useCurrentLocation,
                  onPinDestination: () => _openPinPicker(forPickup: false),
                  onSavedPlaceSelected: _applyDestination,
                  onBookRide: _openBookRide,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
