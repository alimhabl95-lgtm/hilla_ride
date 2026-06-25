import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/region_search_context.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/widgets/google_map_view.dart';
import 'package:hilla_ride/features/customer/widgets/ride_search_panel.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';

class GoogleMapPinPickerScreen extends StatefulWidget {
  const GoogleMapPinPickerScreen({
    super.key,
    required this.title,
    required this.region,
    this.initialPoint,
    this.isPickup = true,
  });

  final String title;
  final RegionSearchContext region;
  final ll.LatLng? initialPoint;
  final bool isPickup;

  @override
  State<GoogleMapPinPickerScreen> createState() =>
      _GoogleMapPinPickerScreenState();
}

class _GoogleMapPinPickerScreenState extends State<GoogleMapPinPickerScreen> {
  static const _bottomPanelHeight = 172.0;

  GoogleMapController? _mapController;
  late ll.LatLng _selectedPoint;
  String _label = '';
  var _isLoadingLabel = false;
  Timer? _labelDebounce;
  Offset _pinScreenOffset = Offset.zero;
  var _pinOffsetReady = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint =
        widget.initialPoint ?? widget.region.searchCenter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePinScreenOffset();
      _loadLabel();
    });
  }

  @override
  void dispose() {
    _labelDebounce?.cancel();
    super.dispose();
  }

  void _updatePinScreenOffset() {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + kToolbarHeight;
    final mapHeight = media.size.height - topInset - _bottomPanelHeight;
    setState(() {
      _pinScreenOffset = Offset(
        media.size.width / 2,
        topInset + (mapHeight / 2),
      );
      _pinOffsetReady = true;
    });
  }

  Future<void> _loadLabel() async {
    setState(() => _isLoadingLabel = true);
    try {
      final geocoding = context.read<AppState>().geocodingService;
      final label = await geocoding.reverseGeocode(
        _selectedPoint,
        acceptLanguage: Localizations.localeOf(context).languageCode,
        region: widget.region,
        preferStreet: true,
      );
      if (mounted) setState(() => _label = label.trim());
    } finally {
      if (mounted) setState(() => _isLoadingLabel = false);
    }
  }

  Future<String?> _resolveStreetLabel() async {
    if (_isLoadingLabel) {
      while (_isLoadingLabel && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    var label = _label.trim();
    if (label.isNotEmpty && !_looksLikeCoordinateLabel(label)) {
      return label;
    }

    await _loadLabel();
    label = _label.trim();
    if (label.isNotEmpty && !_looksLikeCoordinateLabel(label)) {
      return label;
    }
    return null;
  }

  bool _looksLikeCoordinateLabel(String value) =>
      RegExp(r'^-?\d+\.\d{4,6},\s*-?\d+\.\d{4,6}$').hasMatch(value.trim());

  void _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    final geocoding = context.read<AppState>().geocodingService;
    if (!geocoding.isWithinRegion(widget.region, _selectedPoint)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchOutsideRegion)),
      );
      return;
    }

    final label = await _resolveStreetLabel();
    if (!mounted) return;
    if (label == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pinStreetNameRequired)),
      );
      return;
    }

    Navigator.of(context).pop(
      PlaceResult(
        label: label,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
      ),
    );
  }

  void _scheduleLabelRefresh() {
    _labelDebounce?.cancel();
    _labelDebounce = Timer(const Duration(milliseconds: 350), _loadLabel);
  }

  Future<void> _updateCenterFromMap() async {
    final controller = _mapController;
    if (controller == null || !mounted || !_pinOffsetReady) return;

    final center = await controller.getLatLng(
      ScreenCoordinate(
        x: _pinScreenOffset.dx.round(),
        y: _pinScreenOffset.dy.round(),
      ),
    );

    setState(() {
      _selectedPoint = ll.LatLng(center.latitude, center.longitude);
    });
    _scheduleLabelRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final topInset = media.padding.top + kToolbarHeight;
    final mapHeight = media.size.height - topInset - _bottomPanelHeight;
    final pinColor = widget.isPickup
        ? MapMarkerColors.pickup
        : MapMarkerColors.destination;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMapView(
            initialPosition: LatLng(
              _selectedPoint.latitude,
              _selectedPoint.longitude,
            ),
            zoom: 16,
            onMapCreated: (controller) => _mapController = controller,
            onCameraIdle: _updateCenterFromMap,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mapHeight,
            child: IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.isPickup ? l10n.pickup : l10n.destination,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    widget.isPickup
                        ? Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: pinColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: pinColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              elevation: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: _bottomPanelHeight,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.dragMapToSelectPin),
                      const SizedBox(height: 8),
                      if (_isLoadingLabel)
                        const LinearProgressIndicator()
                      else
                        Text(
                          _label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _confirm,
                        child: Text(l10n.confirmLocation),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
