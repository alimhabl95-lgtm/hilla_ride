import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/map_presence.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/nearby_providers_service.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/core/widgets/ui/app_ui.dart';
import 'package:hilla_ride/core/widgets/map_camera_follow.dart';
import 'package:hilla_ride/core/widgets/driver_marker_cluster.dart';
import 'package:hilla_ride/core/widgets/map_marker_icons.dart';
import 'package:hilla_ride/core/widgets/marker_animator.dart';
import 'package:hilla_ride/features/auth/screens/app_shell.dart';
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
  late String _districtId = BabilRegions.customerDistrict.id;
  String? _subDistrictId;
  var _pickupLoading = false;
  var _markersReady = false;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;
  final _nearbyService = NearbyProvidersService();
  final _markerAnimator = MarkerAnimator();
  final _cameraFollow = MapCameraFollowController();
  StreamSubscription<List<MapPresence>>? _nearbySub;
  LatLng? _cameraTarget;
  LatLng? _lastWatchCenter;
  double _cameraZoom = 14;
  LatLng? _lastKnownDeviceLocation;
  bool _suppressLocationClear = false;

  @override
  void initState() {
    super.initState();
    _markerAnimator.onTick = () {
      if (mounted) setState(() {});
    };
    MapMarkerIcons.ensureLoaded().then((_) {
      if (mounted) setState(() => _markersReady = true);
      _refreshTripMarkers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().pricingService.prefetchConfig(
            districtId: _districtId,
          );
      _restartNearbyWatch(force: true);
    });
  }

  @override
  void dispose() {
    _nearbySub?.cancel();
    _markerAnimator.dispose();
    super.dispose();
  }

  LatLng get _watchCenter {
    // Prefer pickup while booking; otherwise visible map camera center.
    if (_pickup != null) {
      return LatLng(_pickup!.latitude, _pickup!.longitude);
    }
    if (_cameraTarget != null) return _cameraTarget!;
    return LatLng(
      _region.searchCenter.latitude,
      _region.searchCenter.longitude,
    );
  }

  void _restartNearbyWatch({bool force = false}) {
    final center = _watchCenter;
    if (!force && _lastWatchCenter != null) {
      final movedM = Geolocator.distanceBetween(
        _lastWatchCenter!.latitude,
        _lastWatchCenter!.longitude,
        center.latitude,
        center.longitude,
      );
      if (movedM < 180) return;
    }
    _lastWatchCenter = center;
    _nearbySub?.cancel();
    _nearbySub = _nearbyService
        .watchNearbyAvailable(
          center: ll.LatLng(center.latitude, center.longitude),
          radiusKm: MapPresenceConfig.nearbyRadiusKm,
          maxMarkers: MapPresenceConfig.maxNearbyMarkers,
        )
        .listen((providers) {
      if (!mounted) return;
      // Stream already filters status == available (+ fresh). Offline / on-trip never appear.
      _markerAnimator.syncTargets({
        for (final p in providers)
          p.providerId: (
            position: LatLng(p.latitude, p.longitude),
            heading: p.heading,
          ),
      });
      setState(() {});
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
    if (_suppressLocationClear) return;
    final destination = _destination;
    if (destination == null) return;
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isNearSelectedArea(
      _region,
      ll.LatLng(destination.latitude, destination.longitude),
    )) {
      setState(() => _destination = null);
    }
  }

  void _clearPickupIfOutsideRegion() {
    if (_suppressLocationClear) return;
    final pickup = _pickup;
    if (pickup == null) return;
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isNearSelectedArea(
      _region,
      ll.LatLng(pickup.latitude, pickup.longitude),
    )) {
      setState(() => _pickup = null);
    }
  }

  void _releaseLocationClearSuppress() {
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _suppressLocationClear = false;
    });
  }

  /// Align governorate / district / area to a coordinate (like iOS adoptPlaceArea).
  bool _adoptPlaceArea(ll.LatLng coordinate) {
    final resolved = BabilRegions.resolveFromPoint(coordinate);
    final nearDistrict = BabilRegions.isNearDistrictForSearch(
      resolved.districtId,
      coordinate,
      extraBufferKm: 35,
    );
    final inBox = BabilRegions.isInBabilServiceBox(coordinate);
    if (!nearDistrict && !inBox) {
      return false;
    }

    setState(() {
      _districtId = resolved.districtId;
      _subDistrictId = resolved.subDistrictId;
    });
    context.read<AppState>().pricingService.prefetchConfig(
          districtId: resolved.districtId,
          subDistrictId: resolved.subDistrictId,
        );
    return true;
  }

  void _setPickupFromSearch(PlaceResult place) {
    final l10n = AppLocalizations.of(context)!;
    final point = ll.LatLng(place.latitude, place.longitude);
    final destination = _destination;
    if (destination != null &&
        !RideLocationRules.areDistinctPlaces(place, destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
      );
      return;
    }

    _suppressLocationClear = true;
    // Always apply the tapped place first so the field never stays blank.
    setState(() => _pickup = place);
    if (!_adoptPlaceArea(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchOutsideRegion)),
      );
    }
    _releaseLocationClearSuppress();
    _moveMap(LatLng(place.latitude, place.longitude));
    _fitTripOnMap();
    unawaited(_refreshTripMarkers());
    _restartNearbyWatch(force: true);
  }

  bool _applyDestination(PlaceResult place) {
    final l10n = AppLocalizations.of(context)!;
    final point = ll.LatLng(place.latitude, place.longitude);
    final pickup = _pickup;
    if (pickup != null && !RideLocationRules.areDistinctPlaces(pickup, place)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
      );
      return false;
    }

    _suppressLocationClear = true;
    setState(() => _destination = place);
    if (!_adoptPlaceArea(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchOutsideRegion)),
      );
    }
    _releaseLocationClearSuppress();
    unawaited(_refreshTripMarkers());
    _moveMap(LatLng(place.latitude, place.longitude));
    _fitTripOnMap();
    return true;
  }

  Future<void> _useCurrentLocation() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pickupLoading = true);

    final geocoding = context.read<AppState>().geocodingService;
    final district = BabilRegions.districtById(_districtId);
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
          _lastKnownDeviceLocation =
              LatLng(position.latitude, position.longitude);
          if (geocoding.isNearSelectedArea(_region, candidate) ||
              BabilRegions.isInBabilServiceBox(candidate)) {
            point = candidate;
            usedGps = true;
            _suppressLocationClear = true;
            _adoptPlaceArea(candidate);
            _releaseLocationClearSuppress();
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
      await _moveMap(LatLng(point.latitude, point.longitude));

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

  Future<void> _openPinPicker({required bool forPickup}) async {
    final l10n = AppLocalizations.of(context)!;
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

    final driverIcon = MapMarkerIcons.driver;
    if (driverIcon != null) {
      // Only available drivers are in the animator stream (offline / on-trip excluded).
      final visible = DriverMarkerCluster.apply(
        _markerAnimator.markers.values,
        zoom: _cameraZoom,
      );
      for (final animated in visible) {
        markers.add(
          Marker(
            markerId: MarkerId('nearby_${animated.id}'),
            position: animated.position,
            icon: driverIcon,
            rotation: animated.heading,
            flat: true,
            anchor: const Offset(0.5, 0.55),
            zIndexInt: 1,
            consumeTapEvents: true,
          ),
        );
      }
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
      unawaited(_moveMap(points.first));
      return;
    }

    unawaited(_cameraFollow.fitPoints(controller, points));
  }

  Future<void> _moveMap(LatLng target) async {
    final controller = _mapController;
    if (controller == null) return;
    await _cameraFollow.moveTo(controller, target);
  }

  /// Recenter camera only — does not change pickup/destination.
  Future<void> _recenterToMyLocation() async {
    final controller = _mapController;
    if (controller == null) return;

    LatLng? target = _lastKnownDeviceLocation;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      target = LatLng(pos.latitude, pos.longitude);
      _lastKnownDeviceLocation = target;
    } catch (_) {
      target ??= _pickup != null
          ? LatLng(_pickup!.latitude, _pickup!.longitude)
          : _cameraTarget;
    }
    if (target == null) return;
    await _cameraFollow.moveTo(controller, target);
  }

  /// Governorate → District → Subdistrict is fully cascading and backed by
  /// live [ServiceAreaCatalog] data: changing the district resets the
  /// sub-district selection (and any pickup/destination that would fall
  /// outside the new area) so the customer must confirm the new sub-district
  /// before booking, exactly like a fresh area selection.
  void _onDistrictChanged(String? id) {
    if (id == null || id.isEmpty || id == _districtId) return;
    if (_suppressLocationClear) {
      setState(() => _districtId = id);
      return;
    }
    setState(() {
      _districtId = id;
      // Keep current sub-district when still valid for the new district.
      final stillValid = BabilRegions.districtById(id)
          .subDistricts
          .any((s) => s.id == _subDistrictId);
      if (!stillValid) {
        _subDistrictId = null;
      }
    });
    context.read<AppState>().pricingService.prefetchConfig(districtId: id);
    _clearDestinationIfOutsideRegion();
    _clearPickupIfOutsideRegion();
    unawaited(_refreshTripMarkers());
    final district = BabilRegions.districtById(id);
    if (district.subDistricts.isNotEmpty) {
      final center = district.subDistricts.first.center;
      unawaited(_moveMap(LatLng(center.latitude, center.longitude)));
    }
    _restartNearbyWatch(force: true);
  }

  void _onSubDistrictChanged(String? id) {
    if (_suppressLocationClear) {
      setState(() => _subDistrictId = id);
      return;
    }
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
    unawaited(_moveMap(LatLng(sub.center.latitude, sub.center.longitude)));
    _restartNearbyWatch(force: true);
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
    if (_districtId.trim().isEmpty ||
        _subDistrictId == null ||
        _subDistrictId!.isEmpty) {
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

    final geocoding = context.read<AppState>().geocodingService;
    final pickupPoint = ll.LatLng(pickup.latitude, pickup.longitude);
    final destinationPoint = ll.LatLng(destination.latitude, destination.longitude);
    if (!geocoding.isNearSelectedArea(_region, pickupPoint) ||
        !geocoding.isNearSelectedArea(_region, destinationPoint)) {
      // Soft adopt if still inside Babil service footprint.
      final adoptedPickup = _adoptPlaceArea(pickupPoint);
      final adoptedDest = _adoptPlaceArea(destinationPoint);
      if (!adoptedPickup || !adoptedDest) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.searchOutsideRegion)),
        );
        return;
      }
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
            onCameraMove: (pos) {
              _cameraFollow.onUserCameraInteraction();
              _cameraTarget = pos.target;
              _cameraZoom = pos.zoom;
            },
            onCameraIdle: () {
              // Reload available drivers for the visible map area.
              if (_pickup == null) {
                _restartNearbyWatch();
              } else if (mounted) {
                setState(() {});
              }
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: MobileFloatingChrome(role: UserRole.customer),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: 340,
            child: SafeArea(
              top: false,
              child: Material(
                elevation: 4,
                shadowColor: AppBrandAssets.brandNavy.withValues(alpha: 0.15),
                shape: const CircleBorder(),
                color: Colors.white,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => unawaited(_recenterToMyLocation()),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.my_location,
                      color: AppBrandAssets.brandTealDark,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xl),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppBrandAssets.brandNavy.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.user.hasActivePromo)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          0,
                        ),
                        child: AppBanner(
                          message: l10n.customerPromoBanner(
                            widget.user.promoCode,
                            widget.user.promoRidesLimit -
                                widget.user.promoRidesUsed,
                          ),
                          icon: Icons.local_offer_outlined,
                          tone: AppBannerTone.warning,
                        ),
                      ),
                    RideSearchPanel(
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
                  onDistrictChanged: _onDistrictChanged,
                  onSubDistrictChanged: _onSubDistrictChanged,
                  onPickupSelected: _setPickupFromSearch,
                  onDestinationSelected: _applyDestination,
                  onPinPickup: () => _openPinPicker(forPickup: true),
                  onUseCurrentLocation: _useCurrentLocation,
                  onPinDestination: () => _openPinPicker(forPickup: false),
                  onSavedPlaceSelected: _applyDestination,
                  onBookRide: _openBookRide,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
