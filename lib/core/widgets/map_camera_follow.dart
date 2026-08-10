import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/widgets/map_camera_helper.dart';

/// Gates programmatic camera moves so user pans are never overridden.
///
/// Marker / polyline updates must NOT call [runProgrammaticMove].
/// Only Recenter FAB and intentional booking-flow moves should.
class MapCameraFollowController {
  bool _ignoreCameraEvents = false;
  bool followEnabled = true;

  /// Call from [GoogleMap.onCameraMove] / move-started when the user pans.
  void onUserCameraInteraction() {
    if (_ignoreCameraEvents) return;
    followEnabled = false;
  }

  /// Re-enable follow and run a one-shot camera move (Recenter / booking).
  Future<void> recenter(
    Future<void> Function() move, {
    bool enableFollow = true,
  }) async {
    if (enableFollow) followEnabled = true;
    await runProgrammaticMove(move);
  }

  /// Run a camera animation without treating it as a user pan.
  Future<void> runProgrammaticMove(Future<void> Function() move) async {
    _ignoreCameraEvents = true;
    try {
      await move();
    } finally {
      // Leave a short window so idle/move callbacks from the animation are ignored.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _ignoreCameraEvents = false;
    }
  }

  Future<void> moveTo(
    GoogleMapController controller,
    LatLng target, {
    double zoom = 15,
  }) {
    return recenter(
      () => controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom)),
    );
  }

  Future<void> fitPoints(
    GoogleMapController controller,
    Iterable<LatLng> points, {
    double padding = 56,
  }) {
    return recenter(
      () => MapCameraHelper.fitPoints(controller, points, padding: padding),
    );
  }

  /// Fit only while follow is still enabled (e.g. first layout). No-op after pan.
  Future<void> fitIfFollowing(
    GoogleMapController controller,
    Iterable<LatLng> points, {
    double padding = 56,
  }) async {
    if (!followEnabled) return;
    await runProgrammaticMove(
      () => MapCameraHelper.fitPoints(controller, points, padding: padding),
    );
  }
}
