import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/app_map.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

enum _AdminMapMode { active, recent }

class AdminLiveMapPanel extends StatefulWidget {
  const AdminLiveMapPanel({super.key});

  @override
  State<AdminLiveMapPanel> createState() => _AdminLiveMapPanelState();
}

class _AdminLiveMapPanelState extends State<AdminLiveMapPanel> {
  final _mapController = fm.MapController();

  _AdminMapMode _mode = _AdminMapMode.active;

  String? _lastFitKey;

  static LatLng get _defaultCenter =>
      BabilRegions.customerDistrict.subDistricts.first.center;

  @override
  Widget build(BuildContext context) {
    final adminService = context.read<AppState>().adminService;

    final isWide = MediaQuery.sizeOf(context).width >= 900;

    final rideStream = _mode == _AdminMapMode.active
        ? adminService.watchActiveRides()
        : adminService.watchRecentRides(limit: 40);

    return StreamBuilder<List<DriverProfile>>(
      stream: adminService.watchAllDrivers(),

      builder: (context, allDriversSnapshot) {
        return StreamBuilder<List<Ride>>(
          stream: rideStream,

          builder: (context, rideSnapshot) {
            final allDrivers = allDriversSnapshot.data ?? const [];

            final driversById = {
              for (final driver in allDrivers) driver.uid: driver,
            };

            final rawRides = rideSnapshot.data ?? const [];

            final rides = _mode == _AdminMapMode.active
                ? rawRides
                : _recentMapRides(rawRides);

            final onlineDrivers = allDrivers
                .where((driver) => driver.isOnline && driver.canDrive)
                .toList();

            final markers = _buildMarkers(
              rides: rides,

              onlineDrivers: onlineDrivers,

              driversById: driversById,

              l10n: AppLocalizations.of(context)!,
            );

            final polylines = _buildPolylines(
              rides: rides,

              driversById: driversById,

              dimmed: _mode == _AdminMapMode.recent,
            );

            final center = _mapCenter(
              rides: rides,
              onlineDrivers: onlineDrivers,
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

                  child: _MapLegend(l10n: AppLocalizations.of(context)!),
                ),
              ],
            );

            final list = _RideMapList(
              mode: _mode,

              rides: rides,

              onlineDrivers: onlineDrivers,

              driversById: driversById,

              onFocusDriver: _focusOnDriver,

              onFocusRide: _focusOnRide,

              onModeChanged: (mode) => setState(() {
                _mode = mode;

                _lastFitKey = null;
              }),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,

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

  List<Ride> _recentMapRides(List<Ride> rides) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    return rides
        .where((ride) {
          if (ride.pickupLat == 0 && ride.pickupLng == 0) return false;

          if (ride.status == RideStatus.searching) return false;

          final createdAt = ride.createdAt;

          if (createdAt != null && createdAt.isAfter(cutoff)) return true;

          return ride.status == RideStatus.completed ||
              ride.status == RideStatus.cancelled;
        })
        .take(30)
        .toList();
  }

  void _scheduleMapFit({
    required List<fm.Marker> markers,

    required LatLng center,
  }) {
    final fitKey =
        '${_mode.name}|${markers.length}|'
        '${center.latitude.toStringAsFixed(4)}|${center.longitude.toStringAsFixed(4)}';

    if (_lastFitKey == fitKey) return;

    _lastFitKey = fitKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final points = markers.map((marker) => marker.point).toList();

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

    required List<DriverProfile> onlineDrivers,
  }) {
    final points = <LatLng>[];

    for (final driver in onlineDrivers) {
      if (driver.latitude != null && driver.longitude != null) {
        points.add(LatLng(driver.latitude!, driver.longitude!));
      }
    }

    for (final ride in rides) {
      if (ride.pickupLat != 0 && ride.pickupLng != 0) {
        points.add(LatLng(ride.pickupLat, ride.pickupLng));
      }

      if (ride.destinationLat != 0 && ride.destinationLng != 0) {
        points.add(LatLng(ride.destinationLat, ride.destinationLng));
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
    required List<Ride> rides,

    required List<DriverProfile> onlineDrivers,

    required Map<String, DriverProfile> driversById,

    required AppLocalizations l10n,
  }) {
    final markers = <fm.Marker>[];

    final plottedDriverIds = <String>{};

    for (final ride in rides) {
      if (ride.pickupLat != 0 && ride.pickupLng != 0) {
        markers.add(
          _labeledMarker(
            point: LatLng(ride.pickupLat, ride.pickupLng),

            color: const Color(0xFF15803D),

            icon: Icons.person_pin_circle,

            label: l10n.customerLabel,

            tooltip: '${l10n.customerLabel}: ${ride.pickupLabel}',
          ),
        );
      }

      if (ride.destinationLat != 0 && ride.destinationLng != 0) {
        markers.add(
          _labeledMarker(
            point: LatLng(ride.destinationLat, ride.destinationLng),

            color: const Color(0xFFB91C1C),

            icon: Icons.place,

            label: l10n.rideTo,

            tooltip: ride.destinationLabel,
          ),
        );
      }

      final assignedDriver = ride.driverId == null
          ? null
          : driversById[ride.driverId!];

      if (assignedDriver != null &&
          assignedDriver.latitude != null &&
          assignedDriver.longitude != null) {
        plottedDriverIds.add(assignedDriver.uid);

        markers.add(
          _labeledMarker(
            point: LatLng(assignedDriver.latitude!, assignedDriver.longitude!),

            color: const Color(0xFF0F766E),

            icon: Icons.local_taxi,

            label: assignedDriver.name,

            tooltip:
                '${assignedDriver.name} • ${_rideStatusLabel(ride.status, l10n)}',
          ),
        );
      } else {
        for (final driverId in ride.offeredDriverIds) {
          final offeredDriver = driversById[driverId];

          if (offeredDriver?.latitude == null ||
              offeredDriver?.longitude == null) {
            continue;
          }

          if (plottedDriverIds.contains(driverId)) continue;

          plottedDriverIds.add(driverId);

          markers.add(
            _labeledMarker(
              point: LatLng(offeredDriver!.latitude!, offeredDriver.longitude!),

              color: const Color(0xFF2563EB),

              icon: Icons.local_taxi,

              label: offeredDriver.name,

              tooltip: '${offeredDriver.name} • ${l10n.searchingDriver}',
            ),
          );
        }
      }
    }

    for (final driver in onlineDrivers) {
      if (plottedDriverIds.contains(driver.uid)) continue;

      if (driver.latitude == null || driver.longitude == null) continue;

      markers.add(
        _labeledMarker(
          point: LatLng(driver.latitude!, driver.longitude!),

          color: const Color(0xFF64748B),

          icon: Icons.local_taxi,

          label: driver.name,

          tooltip: driver.name,
        ),
      );
    }

    return markers;
  }

  fm.Marker _labeledMarker({
    required LatLng point,

    required Color color,

    required IconData icon,

    required String label,

    required String tooltip,
  }) {
    final shortLabel = label.length > 14 ? '${label.substring(0, 12)}…' : label;

    return fm.Marker(
      point: point,

      width: 120,

      height: 56,

      alignment: Alignment.bottomCenter,

      child: Tooltip(
        message: tooltip,

        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(8),

                border: Border.all(color: color),

                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),

                    blurRadius: 4,

                    offset: Offset(0, 1),
                  ),
                ],
              ),

              child: Text(
                shortLabel,

                style: TextStyle(
                  color: color,

                  fontSize: 10,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Icon(icon, color: color, size: 30),
          ],
        ),
      ),
    );
  }

  List<fm.Polyline> _buildPolylines({
    required List<Ride> rides,

    required Map<String, DriverProfile> driversById,

    required bool dimmed,
  }) {
    final polylines = <fm.Polyline>[];

    final routeColor = dimmed
        ? const Color(0x8894A3B8)
        : const Color(0xFF0F766E);

    final pickupColor = dimmed
        ? const Color(0x882563EB)
        : const Color(0xFF2563EB);

    for (final ride in rides) {
      final pickupPoint = LatLng(ride.pickupLat, ride.pickupLng);

      final destinationPoint = LatLng(ride.destinationLat, ride.destinationLng);

      if (ride.pickupLat != 0 &&
          ride.pickupLng != 0 &&
          ride.destinationLat != 0 &&
          ride.destinationLng != 0) {
        polylines.add(
          fm.Polyline(
            points: [pickupPoint, destinationPoint],

            color: routeColor,

            strokeWidth: dimmed ? 3 : 4,
          ),
        );
      }

      final driver = ride.driverId == null ? null : driversById[ride.driverId!];

      if (driver?.latitude == null || driver?.longitude == null) continue;

      if (ride.pickupLat == 0 || ride.pickupLng == 0) continue;

      polylines.add(
        fm.Polyline(
          points: [LatLng(driver!.latitude!, driver.longitude!), pickupPoint],

          color: pickupColor,

          strokeWidth: dimmed ? 3 : 4,
        ),
      );
    }

    return polylines;
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),

        borderRadius: BorderRadius.circular(12),

        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),

            blurRadius: 8,

            offset: Offset(0, 2),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

        child: Wrap(
          spacing: 12,

          runSpacing: 6,

          children: [
            _legendItem(const Color(0xFF15803D), l10n.customerLabel),

            _legendItem(const Color(0xFF0F766E), l10n.roleDriver),

            _legendItem(const Color(0xFFB91C1C), l10n.rideTo),

            _legendItem(const Color(0xFF2563EB), l10n.routeToPickup),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
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

class _RideMapList extends StatelessWidget {
  const _RideMapList({
    required this.mode,

    required this.rides,

    required this.onlineDrivers,

    required this.driversById,

    required this.onFocusDriver,

    required this.onFocusRide,

    required this.onModeChanged,
  });

  final _AdminMapMode mode;

  final List<Ride> rides;

  final List<DriverProfile> onlineDrivers;

  final Map<String, DriverProfile> driversById;

  final void Function(DriverProfile driver) onFocusDriver;

  final void Function(Ride ride, DriverProfile? driver) onFocusRide;

  final ValueChanged<_AdminMapMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        SegmentedButton<_AdminMapMode>(
          segments: [
            ButtonSegment(
              value: _AdminMapMode.active,

              label: Text(l10n.activeRidesTab),
            ),

            ButtonSegment(
              value: _AdminMapMode.recent,

              label: Text(l10n.driverHistoryTitle),
            ),
          ],

          selected: {mode},

          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),

        const SizedBox(height: 12),

        if (rides.isEmpty && onlineDrivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),

            child: Center(child: Text(l10n.noOnlineDrivers)),
          ),

        if (rides.isNotEmpty) ...[
          Text(
            mode == _AdminMapMode.active
                ? l10n.activeRidesTab
                : l10n.driverHistoryTitle,

            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          ...rides.map((ride) {
            final driver = ride.driverId == null
                ? null
                : driversById[ride.driverId!];

            return Card(
              margin: const EdgeInsets.only(bottom: 8),

              child: ListTile(
                leading: const Icon(Icons.person_outline),

                title: Text('${ride.pickupLabel} → ${ride.destinationLabel}'),

                subtitle: Text(
                  '${_rideStatusLabel(ride.status, l10n)}\n'
                  '${l10n.customerLabel}: ${ride.customerId.isEmpty ? '—' : ride.customerId}\n'
                  '${l10n.roleDriver}: ${driver?.name ?? l10n.searchingDriver}',
                ),

                isThreeLine: true,

                trailing: const Icon(Icons.my_location),

                onTap: () => onFocusRide(ride, driver),
              ),
            );
          }),

          const SizedBox(height: 12),
        ],

        Text(l10n.liveMapTab, style: Theme.of(context).textTheme.titleMedium),

        const SizedBox(height: 8),

        if (onlineDrivers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),

            child: Text(l10n.noOnlineDrivers),
          )
        else
          ...onlineDrivers.map((driver) {
            final updated = driver.locationUpdatedAt;

            final updatedLabel = updated == null
                ? l10n.noLocationYet
                : DateFormat.yMMMd(l10n.localeName).add_jm().format(updated);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),

              child: ListTile(
                leading: CircleAvatar(
                  child: Text(driver.name.isEmpty ? '?' : driver.name[0]),
                ),

                title: Text(driver.name),

                subtitle: Text(
                  '${l10n.phoneHint}: ${driver.phone.isEmpty ? '—' : driver.phone}\n'
                  '${driver.latitude == null ? l10n.noLocationYet : '${driver.latitude!.toStringAsFixed(5)}, ${driver.longitude!.toStringAsFixed(5)}'}\n'
                  '$updatedLabel',
                ),

                isThreeLine: true,

                trailing: const Icon(Icons.my_location),

                onTap: () => onFocusDriver(driver),
              ),
            );
          }),
      ],
    );
  }
}

String _rideStatusLabel(RideStatus status, AppLocalizations l10n) {
  switch (status) {
    case RideStatus.searching:
      return l10n.searchingDriver;

    case RideStatus.matched:
      return l10n.newRideRequest;

    case RideStatus.accepted:
      return l10n.driverAssignedTitle;

    case RideStatus.inProgress:
      return l10n.startRide;

    case RideStatus.awaitingCashPayment:
      return l10n.waitingCustomerCashConfirm;

    case RideStatus.completed:
      return l10n.rideCompleted;

    case RideStatus.cancelled:
      return l10n.cancel;
  }
}