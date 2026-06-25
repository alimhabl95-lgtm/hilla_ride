import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/app_map.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({
    super.key,
    this.initialPoint,
  });

  final LatLng? initialPoint;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _mapController = MapController();
  late LatLng _selectedPoint;
  String _label = '';
  bool _isLoadingLabel = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint ?? HillaConstants.cityCenter;
    _loadLabel();
  }

  Future<void> _loadLabel() async {
    setState(() => _isLoadingLabel = true);
    try {
      final geocoding = context.read<AppState>().geocodingService;
      final label = await geocoding.reverseGeocode(_selectedPoint);
      if (mounted) setState(() => _label = label);
    } finally {
      if (mounted) setState(() => _isLoadingLabel = false);
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() => _selectedPoint = point);
    _loadLabel();
  }

  void _confirm() {
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isWithinServiceArea(_selectedPoint)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected location is outside Hilla service area')),
      );
      return;
    }

    Navigator.of(context).pop(
      PlaceResult(
        label: _label,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pinOnMap)),
      body: Stack(
        children: [
          AppMap(
            mapController: _mapController,
            center: _selectedPoint,
            zoom: HillaConstants.userLocationZoom,
            onTap: _onMapTap,
            onMapReady: () {
              _mapController.move(_selectedPoint, HillaConstants.userLocationZoom);
            },
            markers: [
              Marker(
                point: _selectedPoint,
                width: 48,
                height: 48,
                child: const Icon(Icons.location_on, color: Colors.red, size: 42),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 8,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.tapMapToPin),
                    const SizedBox(height: 8),
                    if (_isLoadingLabel)
                      const LinearProgressIndicator()
                    else
                      Text(_label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _confirm,
                      child: Text(l10n.confirmLocation),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
