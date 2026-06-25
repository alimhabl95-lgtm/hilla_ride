import 'package:geolocator/geolocator.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:latlong2/latlong.dart';

/// Minimum straight-line distance between pickup and destination for a valid trip.
class RideLocationRules {
  RideLocationRules._();

  static const double minTripDistanceMeters = 100;

  static double distanceMeters(LatLng pickup, LatLng destination) {
    return Geolocator.distanceBetween(
      pickup.latitude,
      pickup.longitude,
      destination.latitude,
      destination.longitude,
    );
  }

  static bool areDistinct(LatLng pickup, LatLng destination) {
    return distanceMeters(pickup, destination) >= minTripDistanceMeters;
  }

  static bool areDistinctPlaces(PlaceResult pickup, PlaceResult destination) {
    return areDistinct(
      LatLng(pickup.latitude, pickup.longitude),
      LatLng(destination.latitude, destination.longitude),
    );
  }

  static bool rideHasDistinctEndpoints(Ride ride) {
    return areDistinct(
      LatLng(ride.pickupLat, ride.pickupLng),
      LatLng(ride.destinationLat, ride.destinationLng),
    );
  }
}
