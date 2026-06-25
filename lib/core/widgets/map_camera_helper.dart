import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapCameraHelper {
  MapCameraHelper._();

  static Future<void> fitPoints(
    GoogleMapController controller,
    Iterable<LatLng> points, {
    double padding = 56,
  }) async {
    final list = points.toList();
    if (list.isEmpty) return;

    if (list.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(list.first, 15),
      );
      return;
    }

    var minLat = list.first.latitude;
    var maxLat = list.first.latitude;
    var minLng = list.first.longitude;
    var maxLng = list.first.longitude;

    for (final point in list) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    const minSpan = 0.008;
    if ((maxLat - minLat).abs() < minSpan) {
      minLat -= minSpan / 2;
      maxLat += minSpan / 2;
    }
    if ((maxLng - minLng).abs() < minSpan) {
      minLng -= minSpan / 2;
      maxLng += minSpan / 2;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        padding,
      ),
    );
  }
}
