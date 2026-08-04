/// Configurable live-map presence settings (ride + future delivery services).
class MapPresenceConfig {
  MapPresenceConfig._();

  static const String collection = 'mapPresence';
  static const String serviceTypeRide = 'ride';
  static const String vehicleTypeTukTuk = 'tukTuk';

  /// Nearby drivers shown before a ride request.
  static const double nearbyRadiusKm = 3.0;
  static const int maxNearbyMarkers = 20;

  /// Ignore presence docs older than this.
  static const Duration staleLocationCutoff = Duration(seconds: 60);

  /// Target driver GPS publish interval while moving.
  static const Duration locationPublishMinInterval = Duration(seconds: 3);
  static const double locationPublishMinMoveMeters = 10;

  /// Animate markers between Firestore updates.
  static const Duration markerAnimationDuration = Duration(milliseconds: 900);

  /// Refresh customer route/ETA while tracking.
  static const Duration routeRefreshInterval = Duration(seconds: 18);
  static const double routeRefreshMinMoveMeters = 40;
}

enum DriverOperationalStatus {
  available,
  searching,
  rideOffered,
  rideAccepted,
  arrivingPickup,
  onTrip,
  completed,
  offline,
}

extension DriverOperationalStatusX on DriverOperationalStatus {
  String get value => switch (this) {
        DriverOperationalStatus.available => 'available',
        DriverOperationalStatus.searching => 'searching',
        DriverOperationalStatus.rideOffered => 'rideOffered',
        DriverOperationalStatus.rideAccepted => 'rideAccepted',
        DriverOperationalStatus.arrivingPickup => 'arrivingPickup',
        DriverOperationalStatus.onTrip => 'onTrip',
        DriverOperationalStatus.completed => 'completed',
        DriverOperationalStatus.offline => 'offline',
      };

  bool get appearsOnCustomerMap => this == DriverOperationalStatus.available;

  static DriverOperationalStatus fromString(String? raw) {
    switch (raw) {
      case 'available':
        return DriverOperationalStatus.available;
      case 'searching':
        return DriverOperationalStatus.searching;
      case 'rideOffered':
        return DriverOperationalStatus.rideOffered;
      case 'rideAccepted':
        return DriverOperationalStatus.rideAccepted;
      case 'arrivingPickup':
        return DriverOperationalStatus.arrivingPickup;
      case 'onTrip':
      case 'customerOnBoard':
        return DriverOperationalStatus.onTrip;
      case 'completed':
        return DriverOperationalStatus.completed;
      case 'offline':
      default:
        return DriverOperationalStatus.offline;
    }
  }

  /// Derive status from legacy online / active-ride flags.
  static DriverOperationalStatus fromLegacy({
    required bool isOnline,
    required bool hasActiveRide,
    String? rideStatus,
  }) {
    if (!isOnline) return DriverOperationalStatus.offline;
    if (!hasActiveRide) return DriverOperationalStatus.available;
    switch (rideStatus) {
      case 'matched':
        return DriverOperationalStatus.rideOffered;
      case 'accepted':
        return DriverOperationalStatus.arrivingPickup;
      case 'inProgress':
      case 'awaitingCashPayment':
        return DriverOperationalStatus.onTrip;
      case 'completed':
        return DriverOperationalStatus.completed;
      default:
        return DriverOperationalStatus.rideAccepted;
    }
  }
}
