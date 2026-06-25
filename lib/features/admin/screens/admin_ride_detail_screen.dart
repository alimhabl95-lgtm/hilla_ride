import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/fare_service.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/features/admin/widgets/admin_ride_promo_summary.dart';
import 'package:hilla_ride/features/shared/widgets/ride_earnings_summary.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class AdminRideDetailScreen extends StatelessWidget {
  const AdminRideDetailScreen({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final adminService = context.read<AppState>().adminService;
    final driverService = context.read<AppState>().driverService;
    const fareService = FareService();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripDetailsTitle)),
      body: FutureBuilder<AppUser?>(
        future: ride.customerId.isEmpty
            ? Future.value(null)
            : adminService.getUser(ride.customerId),
        builder: (context, customerSnapshot) {
          final customer = customerSnapshot.data;

          return StreamBuilder<DriverProfile?>(
            stream: ride.driverId == null || ride.driverId!.isEmpty
                ? Stream.value(null)
                : driverService.watchDriver(ride.driverId!),
            builder: (context, driverSnapshot) {
              final driver = driverSnapshot.data;

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tripStatusLabel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${l10n.statusLabel}: ${ride.status.name}'),
                          Text(
                            '${l10n.cashFare}: ${fareService.formatIqd(ride.fareAmountIqd, locale: l10n.localeName)}',
                          ),
                          if (ride.status == RideStatus.completed)
                            RideEarningsSummary(ride: ride),
                        ],
                      ),
                    ),
                  ),
                  if (ride.usedPromo) ...[
                    const SizedBox(height: 16),
                    AdminRidePromoSummary(ride: ride),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.customerDetails,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${l10n.fullName}: ${customer?.name ?? '—'}'),
                          Text('${l10n.phoneHint}: ${customer?.phone ?? '—'}'),
                          const SizedBox(height: 8),
                          Text('${l10n.pickup}: ${ride.pickupLabel}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.driverDetails,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (driver == null)
                            Text(l10n.noDriverAssigned)
                          else ...[
                            Text('${l10n.fullName}: ${driver.name}'),
                            Text('${l10n.phoneHint}: ${driver.phone}'),
                            Text('${l10n.vehicleType}: ${driver.vehicleType}'),
                            Text('${l10n.vehiclePlate}: ${driver.vehiclePlate}'),
                            Text(
                              driver.isOnline ? l10n.goOnline : l10n.goOffline,
                            ),
                            if (driver.latitude != null &&
                                driver.longitude != null)
                              Text(
                                '${driver.latitude!.toStringAsFixed(5)}, ${driver.longitude!.toStringAsFixed(5)}',
                              ),
                          ],
                          const SizedBox(height: 8),
                          Text('${l10n.destination}: ${ride.destinationLabel}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.tripMapTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMapView(
                        initialPosition: LatLng(ride.pickupLat, ride.pickupLng),
                        zoom: 13,
                        markers: _tripMarkers(ride, driver),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Set<Marker> _tripMarkers(Ride ride, DriverProfile? driver) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(ride.pickupLat, ride.pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: ride.pickupLabel),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(ride.destinationLat, ride.destinationLng),
        icon: BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(title: ride.destinationLabel),
      ),
    };

    if (driver?.latitude != null && driver?.longitude != null) {
      markers.add(
        Marker(
          markerId: MarkerId('driver_${driver!.uid}'),
          position: LatLng(driver.latitude!, driver.longitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: driver.name),
        ),
      );
    }

    return markers;
  }
}
