import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:hilla_ride/core/widgets/app_map.dart';
import 'package:hilla_ride/core/widgets/place_picker_field.dart';
import 'package:hilla_ride/features/customer/screens/active_ride_screen.dart';
import 'package:hilla_ride/features/customer/screens/map_picker_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static final _defaultRegion = RegionSearchContext(
    districtId: BabilRegions.customerDistrictId,
    subDistrictId: BabilRegions.customerDistrict.subDistricts.first.id,
  );

  final _mapController = MapController();
  PlaceResult? _pickup;
  PlaceResult? _destination;
  bool _isLocating = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }

  Future<LatLng?> _resolveDeviceLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final geocoding = context.read<AppState>().geocodingService;
    LatLng? candidate;

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      candidate = LatLng(lastKnown.latitude, lastKnown.longitude);
    }

    if (candidate == null || !geocoding.isWithinServiceArea(candidate)) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        ).timeout(const Duration(seconds: 6));
        candidate = LatLng(position.latitude, position.longitude);
      } on TimeoutException {
        candidate = null;
      } catch (_) {
        candidate = null;
      }
    }

    if (candidate == null || !geocoding.isWithinServiceArea(candidate)) {
      return null;
    }

    return candidate;
  }

  Future<void> _refinePickupLabel(LatLng point) async {
    try {
      final label = await context.read<AppState>().geocodingService.reverseGeocode(
            point,
            acceptLanguage: 'ar',
          );
      if (!mounted) return;
      setState(() {
        _pickup = PlaceResult(
          label: label,
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
    } catch (_) {
      // Keep the default Hilla label if reverse geocoding fails.
    }
  }

  Future<void> _loadCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLocating = true);
    try {
      final devicePoint = await _resolveDeviceLocation();
      final point = devicePoint ?? HillaConstants.cityCenter;
      final useHillaDefault = devicePoint == null;

      if (!mounted) return;

      setState(() {
        _pickup = PlaceResult(
          label: useHillaDefault
              ? HillaConstants.cityCenterLabelArabic
              : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          latitude: point.latitude,
          longitude: point.longitude,
        );
      });
      _mapController.move(point, HillaConstants.userLocationZoom);
      if (!useHillaDefault) {
        unawaited(_refinePickupLabel(point));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openMapPicker(bool isPickup) async {
    final l10n = AppLocalizations.of(context)!;
    final initial = isPickup ? _pickup : _destination;
    final result = await Navigator.of(context).push<PlaceResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialPoint: initial == null
              ? null
              : LatLng(initial.latitude, initial.longitude),
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (isPickup) {
      final destination = _destination;
      if (destination != null &&
          !RideLocationRules.areDistinctPlaces(result, destination)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
        );
        return;
      }
      setState(() => _pickup = result);
    } else {
      final pickup = _pickup;
      if (pickup != null && !RideLocationRules.areDistinctPlaces(pickup, result)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
        );
        return;
      }
      setState(() => _destination = result);
    }
  }

  Future<void> _requestRide() async {
    final l10n = AppLocalizations.of(context)!;
    final pickup = _pickup;
    final destination = _destination;

    if (pickup == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationRequired)),
      );
      return;
    }
    if (!RideLocationRules.areDistinctPlaces(pickup, destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pickupDestinationMustDiffer)),
      );
      return;
    }

    setState(() => _isRequesting = true);
    try {
      final ride = await context.read<AppState>().rideService.requestRide(
            customerId: widget.user.uid,
            pickupLabel: pickup.label,
            destinationLabel: destination.label,
            pickup: LatLng(pickup.latitude, pickup.longitude),
            destination: LatLng(destination.latitude, destination.longitude),
          );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveRideScreen(rideId: ride.id),
        ),
      );
    } on StateError catch (error) {
      if (error.message == 'no_drivers' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noDriversAvailable)),
        );
      } else if (error.message == 'active_ride_exists' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.activeRideExists)),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final markers = <Marker>[];

    if (_pickup != null) {
      markers.add(
        Marker(
          point: LatLng(_pickup!.latitude, _pickup!.longitude),
          width: 40,
          height: 40,
          child: const Icon(Icons.trip_origin, color: Color(0xFF0F766E), size: 32),
        ),
      );
    }
    if (_destination != null) {
      markers.add(
        Marker(
          point: LatLng(_destination!.latitude, _destination!.longitude),
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 32),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          AppMap(
            mapController: _mapController,
            markers: markers,
            onMapReady: () {
              _mapController.move(
                _pickup == null
                    ? HillaConstants.cityCenter
                    : LatLng(_pickup!.latitude, _pickup!.longitude),
                HillaConstants.defaultMapZoom,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.person,
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (context) {
                          return Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.profile,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text('${widget.user.name} • ${widget.user.age}'),
                                Text(widget.user.phone),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Spacer(),
                  _CircleButton(
                    icon: _isLocating ? Icons.hourglass_top : Icons.my_location,
                    onPressed: _isLocating ? null : _loadCurrentLocation,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                      const SizedBox(height: 16),
                      Text(
                        '${l10n.requestRide} • ${HillaConstants.cityName}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      PlacePickerField(
                        label: l10n.pickup,
                        hint: l10n.currentLocation,
                        selectedLabel: _pickup?.label,
                        region: _defaultRegion,
                        onPlaceSelected: (place) => setState(() => _pickup = place),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openMapPicker(true),
                        icon: const Icon(Icons.pin_drop_outlined),
                        label: Text(l10n.pinOnMap),
                      ),
                      const SizedBox(height: 12),
                      PlacePickerField(
                        label: l10n.destination,
                        hint: l10n.searchPlaces,
                        selectedLabel: _destination?.label,
                        region: _defaultRegion,
                        onPlaceSelected: (place) => setState(() => _destination = place),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openMapPicker(false),
                        icon: const Icon(Icons.pin_drop_outlined),
                        label: Text(l10n.pinOnMap),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isRequesting ? null : _requestRide,
                        icon: _isRequesting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.local_taxi),
                        label: Text(l10n.requestRide),
                      ),
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Colors.white,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF0F766E)),
      ),
    );
  }
}
