import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Camera commands for the Android JavaScript map (no native GoogleMapController).
class HillaMapCommands {
  Future<void> Function()? _fit;
  Future<void> Function(LatLng target, double zoom)? _move;

  void bind({
    required Future<void> Function() fit,
    required Future<void> Function(LatLng target, double zoom) moveTo,
  }) {
    _fit = fit;
    _move = moveTo;
  }

  void unbind() {
    _fit = null;
    _move = null;
  }

  bool get canFit => _fit != null;

  Future<void> fit() async => _fit?.call();

  Future<void> moveTo(LatLng target, {double zoom = 15}) async =>
      _move?.call(target, zoom);
}
