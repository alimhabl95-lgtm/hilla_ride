/// Lightweight geohash helper for Firestore geo-queries (city-scale apps).
class Geohash {
  Geohash._();

  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  static String encode(double latitude, double longitude, {int precision = 6}) {
    var latMin = -90.0;
    var latMax = 90.0;
    var lngMin = -180.0;
    var lngMax = 180.0;
    final buffer = StringBuffer();
    var bit = 0;
    var ch = 0;
    var isLng = true;

    while (buffer.length < precision) {
      if (isLng) {
        final mid = (lngMin + lngMax) / 2;
        if (longitude >= mid) {
          ch = (ch << 1) + 1;
          lngMin = mid;
        } else {
          ch <<= 1;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          ch = (ch << 1) + 1;
          latMin = mid;
        } else {
          ch <<= 1;
          latMax = mid;
        }
      }

      isLng = !isLng;
      bit += 1;
      if (bit == 5) {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  static List<String> searchPrefixes(double latitude, double longitude) {
    final center = encode(latitude, longitude, precision: 6);
    if (center.length < 2) return [center];

    final parent = center.substring(0, center.length - 1);
    final lastChar = center[center.length - 1];
    final index = _base32.indexOf(lastChar);
    if (index < 0) return [center];

    final prefixes = <String>{center, parent};
    if (index > 0) {
      prefixes.add(parent + _base32[index - 1]);
    }
    if (index < _base32.length - 1) {
      prefixes.add(parent + _base32[index + 1]);
    }
    return prefixes.toList();
  }

  static String upperBound(String prefix) => '$prefix\uf8ff';
}

class DriverSearchConfig {
  const DriverSearchConfig._();

  static const maxPickupRadiusKm = 12.0;
  static const perPrefixQueryLimit = 24;
  static const maxCandidates = 60;
}
