import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/animated_tuk_tuk.dart';
import 'package:hilla_ride/core/widgets/app_map.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_detail_screen.dart';
import 'package:hilla_ride/features/admin/screens/admin_driver_wallet_screen.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum _DriverFilter { all, available, enRoute, onTrip, offline }

class AdminLiveMapPanel extends StatefulWidget {
  const AdminLiveMapPanel({super.key});

  @override
  State<AdminLiveMapPanel> createState() => _AdminLiveMapPanelState();
}

class _AdminLiveMapPanelState extends State<AdminLiveMapPanel> {
  final _mapController = fm.MapController();
  static const _fare = FareService();

  String? _lastFitKey;
  DriverProfile? _selectedDriver;
  Ride? _selectedRide;
  _DriverFilter _driverFilter = _DriverFilter.all;

  static const _green = Color(0xFF16A34A);
  static const _orange = Color(0xFFEA580C);
  static const _blue = Color(0xFF2563EB);
  static const _red = Color(0xFFDC2626);
  static const _pickupPin = Color(0xFF0F766E);
  static const _destPin = Color(0xFF7C3AED);

  static LatLng get _defaultCenter =>
      BabilRegions.customerDistrict.subDistricts.first.center;

  @override
  Widget build(BuildContext context) {
    final adminService = context.read<AppState>().adminService;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName.startsWith('ar');

    return StreamBuilder<List<DriverProfile>>(
      stream: adminService.watchAllDrivers(),
      builder: (context, driversSnap) {
        return StreamBuilder<List<Ride>>(
          stream: adminService.watchActiveRides(),
          builder: (context, ridesSnap) {
            final allDrivers = driversSnap.data ?? const [];
            final driversById = {
              for (final d in allDrivers) d.uid: d,
            };
            final rides = ridesSnap.data ?? const [];
            final requests = rides
                .where(
                  (r) =>
                      r.status == RideStatus.searching ||
                      r.status == RideStatus.matched,
                )
                .toList();
            final activeTrips = rides
                .where(
                  (r) =>
                      r.status == RideStatus.accepted ||
                      r.status == RideStatus.inProgress ||
                      r.status == RideStatus.awaitingCashPayment,
                )
                .toList();

            final mappableDrivers = allDrivers.where((d) {
              if (!d.canDrive) return false;
              return d.latitude != null && d.longitude != null;
            }).toList();

            final filteredDrivers = mappableDrivers.where((d) {
              final bucket = _driverBucket(d);
              return switch (_driverFilter) {
                _DriverFilter.all => true,
                _DriverFilter.available => bucket == _DriverFilter.available,
                _DriverFilter.enRoute => bucket == _DriverFilter.enRoute,
                _DriverFilter.onTrip => bucket == _DriverFilter.onTrip,
                _DriverFilter.offline => bucket == _DriverFilter.offline,
              };
            }).toList();

            final markers = _buildMarkers(
              requests: requests,
              activeTrips: activeTrips,
              drivers: filteredDrivers,
              driversById: driversById,
              isAr: isAr,
            );
            final polylines = _buildPolylines(
              activeTrips: activeTrips,
              driversById: driversById,
            );
            final center = _mapCenter(
              rides: [...requests, ...activeTrips],
              drivers: filteredDrivers,
            );
            _scheduleMapFit(markers: markers, center: center);

            final mapStack = Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(isWide ? 12 : 0),
                  child: AppMap(
                    mapController: _mapController,
                    center: center,
                    zoom: 13,
                    markers: markers,
                    polylines: polylines,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _OpsLegend(isAr: isAr),
                ),
                if (_selectedDriver != null)
                  Positioned(
                    left: 12,
                    right: isWide ? null : 12,
                    bottom: 12,
                    width: isWide ? 340 : null,
                    child: _DriverDetailCard(
                      driver: _selectedDriver!,
                      ride: _selectedRide,
                      fare: _fare,
                      isAr: isAr,
                      locale: l10n.localeName,
                      onClose: () => setState(() {
                        _selectedDriver = null;
                        _selectedRide = null;
                      }),
                      onOpenProfile: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminDriverDetailScreen(
                              driver: _selectedDriver!,
                            ),
                          ),
                        );
                      },
                      onOpenWallet: () {
                        final d = _selectedDriver!;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminDriverWalletScreen(
                              driverId: d.uid,
                              driverName: d.name,
                              driverPhone: d.phone,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );

            final list = _OpsSideList(
              isAr: isAr,
              requests: requests,
              activeTrips: activeTrips,
              drivers: filteredDrivers,
              allMappableCount: mappableDrivers.length,
              driverFilter: _driverFilter,
              onFilterChanged: (f) => setState(() => _driverFilter = f),
              onFocusRide: (ride) {
                final driver = ride.driverId == null
                    ? null
                    : driversById[ride.driverId!];
                setState(() {
                  _selectedRide = ride;
                  _selectedDriver = driver;
                });
                _focusOnRide(ride, driver);
              },
              onFocusDriver: (driver) {
                final ride = _activeRideForDriver(driver.uid, rides);
                setState(() {
                  _selectedDriver = driver;
                  _selectedRide = ride;
                });
                _focusOnDriver(driver);
              },
            );

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: mapStack),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: list),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(flex: 3, child: mapStack),
                Expanded(flex: 2, child: Material(elevation: 4, child: list)),
              ],
            );
          },
        );
      },
    );
  }

  Ride? _activeRideForDriver(String driverId, List<Ride> rides) {
    for (final r in rides) {
      if (r.driverId == driverId) return r;
    }
    return null;
  }

  _DriverFilter _driverBucket(DriverProfile driver) {
    if (!driver.isOnline) return _DriverFilter.offline;
    final status =
        DriverOperationalStatusX.fromString(driver.operationalStatus);
    switch (status) {
      case DriverOperationalStatus.arrivingPickup:
      case DriverOperationalStatus.rideAccepted:
      case DriverOperationalStatus.rideOffered:
        return _DriverFilter.enRoute;
      case DriverOperationalStatus.onTrip:
        return _DriverFilter.onTrip;
      case DriverOperationalStatus.available:
      case DriverOperationalStatus.searching:
      case DriverOperationalStatus.completed:
        return _DriverFilter.available;
      case DriverOperationalStatus.offline:
        return driver.isOnline
            ? _DriverFilter.available
            : _DriverFilter.offline;
    }
  }

  Color _driverColor(DriverProfile driver) {
    return switch (_driverBucket(driver)) {
      _DriverFilter.available => _green,
      _DriverFilter.enRoute => _orange,
      _DriverFilter.onTrip => _blue,
      _DriverFilter.offline => _red,
      _DriverFilter.all => _green,
    };
  }

  void _scheduleMapFit({
    required List<fm.Marker> markers,
    required LatLng center,
  }) {
    final fitKey =
        '${markers.length}|${center.latitude.toStringAsFixed(4)}|${center.longitude.toStringAsFixed(4)}|$_driverFilter';
    if (_lastFitKey == fitKey) return;
    _lastFitKey = fitKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final points = markers.map((m) => m.point).toList();
      if (points.length >= 2) {
        _mapController.fitCamera(
          fm.CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.all(56),
          ),
        );
      } else if (points.length == 1) {
        _mapController.move(points.first, 14);
      } else {
        _mapController.move(_defaultCenter, 13);
      }
    });
  }

  void _focusOnDriver(DriverProfile driver) {
    if (driver.latitude == null || driver.longitude == null) return;
    _mapController.move(LatLng(driver.latitude!, driver.longitude!), 15);
  }

  void _focusOnRide(Ride ride, DriverProfile? driver) {
    final points = <LatLng>[
      if (driver?.latitude != null && driver?.longitude != null)
        LatLng(driver!.latitude!, driver.longitude!),
      if (ride.pickupLat != 0 && ride.pickupLng != 0)
        LatLng(ride.pickupLat, ride.pickupLng),
      if (ride.destinationLat != 0 && ride.destinationLng != 0)
        LatLng(ride.destinationLat, ride.destinationLng),
    ];
    if (points.isEmpty) return;
    if (points.length >= 2) {
      _mapController.fitCamera(
        fm.CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(48),
        ),
      );
      return;
    }
    _mapController.move(points.first, 14);
  }

  LatLng _mapCenter({
    required List<Ride> rides,
    required List<DriverProfile> drivers,
  }) {
    final points = <LatLng>[];
    for (final d in drivers) {
      if (d.latitude != null && d.longitude != null) {
        points.add(LatLng(d.latitude!, d.longitude!));
      }
    }
    for (final ride in rides) {
      if (ride.pickupLat != 0 && ride.pickupLng != 0) {
        points.add(LatLng(ride.pickupLat, ride.pickupLng));
      }
    }
    if (points.isEmpty) return _defaultCenter;
    final avgLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final avgLng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(avgLat, avgLng);
  }

  List<fm.Marker> _buildMarkers({
    required List<Ride> requests,
    required List<Ride> activeTrips,
    required List<DriverProfile> drivers,
    required Map<String, DriverProfile> driversById,
    required bool isAr,
  }) {
    final markers = <fm.Marker>[];
    final plottedDrivers = <String>{};

    void addRidePins(Ride ride) {
      if (ride.pickupLat != 0 && ride.pickupLng != 0) {
        markers.add(
          _pinMarker(
            point: LatLng(ride.pickupLat, ride.pickupLng),
            color: _pickupPin,
            icon: Icons.person_pin_circle,
            label: isAr ? 'انطلاق' : 'Pickup',
            onTap: () {
              final driver = ride.driverId == null
                  ? null
                  : driversById[ride.driverId!];
              setState(() {
                _selectedRide = ride;
                _selectedDriver = driver;
              });
            },
          ),
        );
      }
      if (ride.destinationLat != 0 && ride.destinationLng != 0) {
        markers.add(
          _pinMarker(
            point: LatLng(ride.destinationLat, ride.destinationLng),
            color: _destPin,
            icon: Icons.place,
            label: isAr ? 'وجهة' : 'Dest',
            onTap: () {
              final driver = ride.driverId == null
                  ? null
                  : driversById[ride.driverId!];
              setState(() {
                _selectedRide = ride;
                _selectedDriver = driver;
              });
            },
          ),
        );
      }
    }

    for (final ride in [...requests, ...activeTrips]) {
      addRidePins(ride);
      final assigned =
          ride.driverId == null ? null : driversById[ride.driverId!];
      if (assigned != null &&
          assigned.latitude != null &&
          assigned.longitude != null) {
        plottedDrivers.add(assigned.uid);
        markers.add(
          _driverMarker(
            driver: assigned,
            label: assigned.name,
            onTap: () {
              setState(() {
                _selectedDriver = assigned;
                _selectedRide = ride;
              });
            },
          ),
        );
      }
    }

    for (final driver in drivers) {
      if (plottedDrivers.contains(driver.uid)) continue;
      if (driver.latitude == null || driver.longitude == null) continue;
      markers.add(
        _driverMarker(
          driver: driver,
          label: driver.name,
          onTap: () {
            setState(() {
              _selectedDriver = driver;
              _selectedRide = null;
            });
          },
        ),
      );
    }
    return markers;
  }

  fm.Marker _driverMarker({
    required DriverProfile driver,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = _driverColor(driver);
    final short = label.length > 14 ? '${label.substring(0, 12)}…' : label;
    return fm.Marker(
      point: LatLng(driver.latitude!, driver.longitude!),
      width: 120,
      height: 56,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color),
              ),
              child: Text(
                short,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TukTukTileIcon(size: 32, accentColor: color),
          ],
        ),
      ),
    );
  }

  fm.Marker _pinMarker({
    required LatLng point,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return fm.Marker(
      point: point,
      width: 90,
      height: 48,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(icon, color: color, size: 28),
          ],
        ),
      ),
    );
  }

  List<fm.Polyline> _buildPolylines({
    required List<Ride> activeTrips,
    required Map<String, DriverProfile> driversById,
  }) {
    final polylines = <fm.Polyline>[];
    for (final ride in activeTrips) {
      if (ride.pickupLat != 0 &&
          ride.pickupLng != 0 &&
          ride.destinationLat != 0 &&
          ride.destinationLng != 0) {
        polylines.add(
          fm.Polyline(
            points: [
              LatLng(ride.pickupLat, ride.pickupLng),
              LatLng(ride.destinationLat, ride.destinationLng),
            ],
            color: const Color(0xFF0F766E),
            strokeWidth: 4,
          ),
        );
      }
      final driver =
          ride.driverId == null ? null : driversById[ride.driverId!];
      if (driver?.latitude == null ||
          driver?.longitude == null ||
          ride.pickupLat == 0 ||
          ride.pickupLng == 0) {
        continue;
      }
      if (ride.status == RideStatus.accepted ||
          ride.status == RideStatus.matched) {
        polylines.add(
          fm.Polyline(
            points: [
              LatLng(driver!.latitude!, driver.longitude!),
              LatLng(ride.pickupLat, ride.pickupLng),
            ],
            color: _orange,
            strokeWidth: 3,
          ),
        );
      }
    }
    return polylines;
  }
}

class _OpsLegend extends StatelessWidget {
  const _OpsLegend({required this.isAr});

  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _item(const Color(0xFF16A34A), isAr ? 'متاح' : 'Available'),
            _item(const Color(0xFFEA580C), isAr ? 'إلى الالتقاط' : 'To pickup'),
            _item(const Color(0xFF2563EB), isAr ? 'مع الراكب' : 'On board'),
            _item(const Color(0xFFDC2626), isAr ? 'غير متصل' : 'Offline'),
            _item(const Color(0xFF0F766E), isAr ? 'انطلاق' : 'Pickup'),
            _item(const Color(0xFF7C3AED), isAr ? 'وجهة' : 'Destination'),
          ],
        ),
      ),
    );
  }

  Widget _item(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DriverDetailCard extends StatelessWidget {
  const _DriverDetailCard({
    required this.driver,
    required this.ride,
    required this.fare,
    required this.isAr,
    required this.locale,
    required this.onClose,
    required this.onOpenProfile,
    required this.onOpenWallet,
  });

  final DriverProfile driver;
  final Ride? ride;
  final FareService fare;
  final bool isAr;
  final String locale;
  final VoidCallback onClose;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenWallet;

  @override
  Widget build(BuildContext context) {
    final status =
        DriverOperationalStatusX.fromString(driver.operationalStatus);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: driver.profilePhotoUrl.isNotEmpty
                      ? NetworkImage(driver.profilePhotoUrl)
                      : null,
                  child: driver.profilePhotoUrl.isEmpty
                      ? Text(driver.name.isNotEmpty ? driver.name[0] : '?')
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(driver.phone),
                      Text(
                        '${isAr ? 'الحالة' : 'Status'}: ${status.value}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${isAr ? 'المحفظة' : 'Wallet'}: ${fare.formatIqd(driver.walletBalanceIqd, locale: locale)} (${driver.walletStatus})',
            ),
            Text(
              '${isAr ? 'التقييم' : 'Rating'}: ${driver.rating.toStringAsFixed(1)}',
            ),
            Text(
              '${isAr ? 'الرحلات' : 'Trips'}: ${driver.completedRidesCount}',
            ),
            Text('${isAr ? 'السرعة' : 'Speed'}: —'),
            if (ride != null) ...[
              const SizedBox(height: 4),
              Text(
                '${isAr ? 'رحلة حالية' : 'Current ride'}: ${ride!.pickupLabel} → ${ride!.destinationLabel}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri(scheme: 'tel', path: driver.phone);
                    await launchUrl(uri);
                  },
                  icon: const Icon(Icons.phone),
                  label: Text(isAr ? 'اتصال' : 'Call'),
                ),
                OutlinedButton(
                  onPressed: onOpenProfile,
                  child: Text(isAr ? 'الملف' : 'Profile'),
                ),
                FilledButton(
                  onPressed: onOpenWallet,
                  child: Text(isAr ? 'المحفظة' : 'Wallet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpsSideList extends StatelessWidget {
  const _OpsSideList({
    required this.isAr,
    required this.requests,
    required this.activeTrips,
    required this.drivers,
    required this.allMappableCount,
    required this.driverFilter,
    required this.onFilterChanged,
    required this.onFocusRide,
    required this.onFocusDriver,
  });

  final bool isAr;
  final List<Ride> requests;
  final List<Ride> activeTrips;
  final List<DriverProfile> drivers;
  final int allMappableCount;
  final _DriverFilter driverFilter;
  final ValueChanged<_DriverFilter> onFilterChanged;
  final ValueChanged<Ride> onFocusRide;
  final ValueChanged<DriverProfile> onFocusDriver;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Text(
            isAr ? 'مركز العمليات الحي' : 'Live operations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              for (final f in _DriverFilter.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    selected: driverFilter == f,
                    label: Text(_filterLabel(f)),
                    onSelected: (_) => onFilterChanged(f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _sectionTitle(
                context,
                '${isAr ? 'طلبات' : 'Requests'} (${requests.length})',
              ),
              if (requests.isEmpty)
                Text(isAr ? 'لا طلبات' : 'No requests')
              else
                for (final r in requests)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.pending_actions,
                        color: Color(0xFF0F766E)),
                    title: Text(
                      '${r.pickupLabel} → ${r.destinationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(r.status.value),
                    onTap: () => onFocusRide(r),
                  ),
              const SizedBox(height: 8),
              _sectionTitle(
                context,
                '${isAr ? 'رحلات نشطة' : 'Active trips'} (${activeTrips.length})',
              ),
              if (activeTrips.isEmpty)
                Text(isAr ? 'لا رحلات نشطة' : 'No active trips')
              else
                for (final r in activeTrips)
                  ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.route, color: Color(0xFF2563EB)),
                    title: Text(
                      '${r.pickupLabel} → ${r.destinationLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(r.status.value),
                    onTap: () => onFocusRide(r),
                  ),
              const SizedBox(height: 8),
              _sectionTitle(
                context,
                '${isAr ? 'السائقون' : 'Drivers'} (${drivers.length}/$allMappableCount)',
              ),
              if (drivers.isEmpty)
                Text(isAr ? 'لا سائقين في هذا الفلتر' : 'No drivers in filter')
              else
                for (final d in drivers)
                  ListTile(
                    dense: true,
                    leading: TukTukTileIcon(
                      size: 28,
                      accentColor: d.isOnline
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                    title: Text(d.name),
                    subtitle: Text(
                      '${d.isOnline ? (isAr ? 'متصل' : 'Online') : (isAr ? 'غير متصل' : 'Offline')} • ${d.operationalStatus}',
                    ),
                    onTap: () => onFocusDriver(d),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  String _filterLabel(_DriverFilter f) {
    if (isAr) {
      return switch (f) {
        _DriverFilter.all => 'الكل',
        _DriverFilter.available => 'متاح',
        _DriverFilter.enRoute => 'إلى الالتقاط',
        _DriverFilter.onTrip => 'مع الراكب',
        _DriverFilter.offline => 'غير متصل',
      };
    }
    return switch (f) {
      _DriverFilter.all => 'All',
      _DriverFilter.available => 'Available',
      _DriverFilter.enRoute => 'En route',
      _DriverFilter.onTrip => 'On trip',
      _DriverFilter.offline => 'Offline',
    };
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
