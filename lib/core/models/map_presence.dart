import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:latlong2/latlong.dart';

class MapPresence {
  const MapPresence({
    required this.providerId,
    required this.serviceType,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.heading = 0,
    this.geohash = '',
    this.vehicleType = MapPresenceConfig.vehicleTypeTukTuk,
    this.displayName = '',
    this.photoUrl = '',
    this.rating = 5.0,
    this.phone = '',
    this.locationUpdatedAt,
  });

  final String providerId;
  final String serviceType;
  final DriverOperationalStatus status;
  final double latitude;
  final double longitude;
  final double heading;
  final String geohash;
  final String vehicleType;
  final String displayName;
  final String photoUrl;
  final double rating;
  final String phone;
  final DateTime? locationUpdatedAt;

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isFresh {
    final updatedAt = locationUpdatedAt;
    if (updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) <=
        MapPresenceConfig.staleLocationCutoff;
  }

  bool get isVisibleOnCustomerMap =>
      status.appearsOnCustomerMap && isFresh && serviceType == MapPresenceConfig.serviceTypeRide;

  factory MapPresence.fromMap(String id, Map<String, dynamic> data) {
    return MapPresence(
      providerId: data['providerId'] as String? ?? id,
      serviceType:
          data['serviceType'] as String? ?? MapPresenceConfig.serviceTypeRide,
      status: DriverOperationalStatusX.fromString(data['status'] as String?),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      heading: (data['heading'] as num?)?.toDouble() ?? 0,
      geohash: data['geohash'] as String? ?? '',
      vehicleType: data['vehicleType'] as String? ??
          MapPresenceConfig.vehicleTypeTukTuk,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      phone: data['phone'] as String? ?? '',
      locationUpdatedAt:
          (data['locationUpdatedAt'] as dynamic)?.toDate() as DateTime?,
    );
  }
}
