import 'package:latlong2/latlong.dart';

class FareService {
  const FareService();

  static const int baseFareIqd = 2000;
  static const int perKmIqd = 500;

  int estimateFare(LatLng pickup, LatLng destination) {
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, pickup, destination);
    return baseFareIqd + (km * perKmIqd).round();
  }

  String formatIqd(int amount, {String locale = 'en'}) {
    if (locale.startsWith('ar')) {
      return '$amount د.ع';
    }
    return '$amount IQD';
  }
}
