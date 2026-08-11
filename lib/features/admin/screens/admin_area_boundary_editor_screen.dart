import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/models/service_area_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/utils/geo_polygon.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

/// Admin screen to draw/edit a sub-district's geofence polygon on a map.
///
/// Shows the current effective boundary (Admin-drawn polygon, or one
/// synthesized from center + search radius) as an editable set of vertices:
/// tap the map to add a point, drag a point to move it, tap a point to
/// remove it. Saving persists the polygon via the existing `saveServiceArea`
/// Cloud Function — every app (iOS/Android) picks it up automatically on
/// the next Firestore sync, no store update required.
class AdminAreaBoundaryEditorScreen extends StatefulWidget {
  const AdminAreaBoundaryEditorScreen({
    super.key,
    required this.subDistrict,
    required this.isAr,
  });

  final ServiceSubDistrict subDistrict;
  final bool isAr;

  @override
  State<AdminAreaBoundaryEditorScreen> createState() =>
      _AdminAreaBoundaryEditorScreenState();
}

class _AdminAreaBoundaryEditorScreenState
    extends State<AdminAreaBoundaryEditorScreen> {
  late List<ll.LatLng> _points;
  var _saving = false;
  var _isSynthetic = false;

  @override
  void initState() {
    super.initState();
    final sub = widget.subDistrict;
    if (sub.boundary != null && sub.boundary!.length >= 3) {
      _points = List.of(sub.boundary!);
      _isSynthetic = false;
    } else {
      _points = GeoPolygon.syntheticPolygonFromCircle(
        sub.center,
        sub.searchRadiusKm,
      );
      _isSynthetic = true;
    }
  }

  LatLng _toGmaps(ll.LatLng p) => LatLng(p.latitude, p.longitude);
  ll.LatLng _fromGmaps(LatLng p) => ll.LatLng(p.latitude, p.longitude);

  void _onMapTap(LatLng point) {
    setState(() {
      _points.add(_fromGmaps(point));
      _isSynthetic = false;
    });
  }

  void _moveVertex(int index, LatLng newPos) {
    setState(() {
      _points[index] = _fromGmaps(newPos);
      _isSynthetic = false;
    });
  }

  void _removeVertex(int index) {
    if (_points.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'يجب أن يحتوي المضلع على 3 نقاط على الأقل'
                : 'The polygon needs at least 3 points',
          ),
        ),
      );
      return;
    }
    setState(() {
      _points.removeAt(index);
      _isSynthetic = false;
    });
  }

  void _resetToCircle() {
    final sub = widget.subDistrict;
    setState(() {
      _points = GeoPolygon.syntheticPolygonFromCircle(
        sub.center,
        sub.searchRadiusKm,
      );
      _isSynthetic = true;
    });
  }

  Future<void> _save() async {
    if (_points.length < 3) return;
    setState(() => _saving = true);
    try {
      // Only the `boundary` field is written here — never the rest of the
      // sub-district (pricing, radius, status, ...), so this can't clobber
      // other Admin edits. Saving the synthetic (unedited) circle clears
      // any previously stored boundary so the app keeps synthesizing it.
      await context.read<AppState>().serviceAreaService.saveSubDistrictBoundary(
            id: widget.subDistrict.id,
            boundary: _isSynthetic ? null : List.of(_points),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAr ? 'تم حفظ الحدود' : 'Boundary saved'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final sub = widget.subDistrict;

    if (!MapsConfig.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: Text(isAr ? 'حدود المنطقة' : 'Area boundary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr
                  ? 'يجب ضبط مفتاح Google Maps API أولاً'
                  : 'Configure the Google Maps API key first',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final polygon = Polygon(
      polygonId: const PolygonId('boundary'),
      points: _points.map(_toGmaps).toList(),
      strokeWidth: 2,
      strokeColor: Colors.blue,
      fillColor: Colors.blue.withOpacity(0.15),
    );

    final markers = <Marker>{
      for (var i = 0; i < _points.length; i++)
        Marker(
          markerId: MarkerId('vertex_$i'),
          position: _toGmaps(_points[i]),
          draggable: true,
          onDragEnd: (pos) => _moveVertex(i, pos),
          onTap: () => _removeVertex(i),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'حدود: ${sub.nameAr}' : 'Boundary: ${sub.nameEn}',
        ),
        actions: [
          IconButton(
            onPressed: _resetToCircle,
            tooltip: isAr ? 'إعادة ضبط كدائرة' : 'Reset to circle',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _toGmaps(sub.center),
              zoom: 12,
            ),
            mapType: MapType.normal,
            zoomControlsEnabled: false,
            polygons: {polygon},
            markers: markers,
            onTap: _onMapTap,
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: Colors.white,
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  isAr
                      ? 'انقر على الخريطة لإضافة نقطة، اسحب نقطة لتحريكها، انقر على نقطة لحذفها. (${_points.length} نقطة${_isSynthetic ? " — دائرة مؤقتة" : ""})'
                      : 'Tap the map to add a point, drag a point to move it, tap a point to remove it. (${_points.length} points${_isSynthetic ? " — temporary circle" : ""})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isAr ? 'حفظ الحدود' : 'Save boundary'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
