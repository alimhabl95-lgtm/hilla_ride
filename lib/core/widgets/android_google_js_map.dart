import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hilla_ride/core/config/maps_config.dart';
import 'package:hilla_ride/core/widgets/hilla_map_commands.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Android-only Google Map via Maps JavaScript API (same key as the web app).
class AndroidGoogleJsMap extends StatefulWidget {
  const AndroidGoogleJsMap({
    super.key,
    required this.initialPosition,
    required this.zoom,
    required this.markers,
    required this.polylines,
    this.commands,
    this.onCameraMove,
    this.onCameraIdle,
    this.onAuthFailure,
  });

  final LatLng initialPosition;
  final double zoom;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final HillaMapCommands? commands;
  final void Function(CameraPosition position)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final VoidCallback? onAuthFailure;

  @override
  State<AndroidGoogleJsMap> createState() => _AndroidGoogleJsMapState();
}

class _AndroidGoogleJsMapState extends State<AndroidGoogleJsMap> {
  WebViewController? _controller;
  var _ready = false;
  var _loadError = '';
  Timer? _readyTimeout;

  @override
  void initState() {
    super.initState();
    widget.commands?.bind(fit: () => _pushState(fit: true), moveTo: _moveTo);
    _readyTimeout = Timer(const Duration(seconds: 12), () {
      if (_ready || !mounted) return;
      widget.onAuthFailure?.call();
    });
    unawaited(_boot());
  }

  @override
  void didUpdateWidget(covariant AndroidGoogleJsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commands != widget.commands) {
      oldWidget.commands?.unbind();
      widget.commands?.bind(fit: () => _pushState(fit: true), moveTo: _moveTo);
    }
    if (_ready) unawaited(_pushState(fit: _shouldFit(oldWidget)));
  }

  @override
  void dispose() {
    _readyTimeout?.cancel();
    widget.commands?.unbind();
    super.dispose();
  }

  bool _shouldFit(AndroidGoogleJsMap oldWidget) {
    if (oldWidget.polylines.length != widget.polylines.length) return true;
    for (final line in widget.polylines) {
      Polyline? old;
      for (final item in oldWidget.polylines) {
        if (item.polylineId == line.polylineId) {
          old = item;
          break;
        }
      }
      if (old == null || old.points.length != line.points.length) return true;
    }
    return false;
  }

  Future<void> _boot() async {
    try {
      final template = await rootBundle.loadString(
        'assets/maps/android_google_map.html',
      );
      final html = template.replaceAll(
        '__MAPS_JS_KEY__',
        MapsConfig.placesWebApiKey,
      );
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFF7F7F7))
        ..addJavaScriptChannel(
          'HillaMapBridge',
          onMessageReceived: _onBridgeMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              debugPrint('Android Google JS map error: ${error.description}');
              if (mounted) setState(() => _loadError = error.description);
            },
          ),
        );
      await controller.loadHtmlString(
        html,
        baseUrl: 'https://hello-tiktok-57dc5.web.app/',
      );
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = '$error');
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final raw = message.message;
    if (raw == 'ready') {
      _ready = true;
      _readyTimeout?.cancel();
      unawaited(_pushState(fit: true));
      return;
    }
    if (raw == 'auth_failure') {
      widget.onAuthFailure?.call();
      return;
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;
      if (data['type'] == 'dragstart') {
        widget.onCameraMove?.call(
          CameraPosition(target: widget.initialPosition, zoom: widget.zoom),
        );
        return;
      }
      if (data['type'] == 'idle') {
        final lat = (data['lat'] as num?)?.toDouble();
        final lng = (data['lng'] as num?)?.toDouble();
        final zoom = (data['zoom'] as num?)?.toDouble() ?? widget.zoom;
        if (lat != null && lng != null) {
          widget.onCameraMove?.call(
            CameraPosition(target: LatLng(lat, lng), zoom: zoom),
          );
        }
        widget.onCameraIdle?.call();
      }
    } catch (_) {}
  }

  Future<void> _moveTo(LatLng target, double zoom) async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    await controller.runJavaScript(
      'moveTo(${target.latitude}, ${target.longitude}, $zoom);',
    );
  }

  String _cssHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _pushState({required bool fit}) async {
    final controller = _controller;
    if (controller == null || !_ready) return;

    final markers = widget.markers.map((marker) {
      final id = marker.markerId.value;
      final isDriver = id == 'driver';
      final isPickup = id.contains('pickup');
      return {
        'id': id,
        'lat': marker.position.latitude,
        'lng': marker.position.longitude,
        'rotation': marker.rotation,
        'kind': isDriver ? 'driver' : (isPickup ? 'pickup' : 'destination'),
        'color': isDriver
            ? '#0F766E'
            : (isPickup ? '#16A34A' : '#DC2626'),
        'title': marker.infoWindow.title ?? '',
      };
    }).toList();

    final lines = widget.polylines
        .where((line) => line.points.length >= 2)
        .map(
          (line) => {
            'color': _cssHex(line.color),
            'width': line.width,
            'points': line.points
                .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                .toList(),
          },
        )
        .toList();

    final fitPoints = <Map<String, double>>[];
    if (fit) {
      for (final line in widget.polylines) {
        for (final p in line.points) {
          fitPoints.add({'lat': p.latitude, 'lng': p.longitude});
        }
      }
      for (final marker in widget.markers) {
        fitPoints.add({
          'lat': marker.position.latitude,
          'lng': marker.position.longitude,
        });
      }
    }

    final payload = jsonEncode({
      'center': {
        'lat': widget.initialPosition.latitude,
        'lng': widget.initialPosition.longitude,
      },
      'zoom': widget.zoom,
      'markers': markers,
      'lines': lines,
      'fit': fitPoints,
    });
    await controller.runJavaScript('applyState(${jsonEncode(payload)});');
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError.isNotEmpty && _controller == null) {
      return ColoredBox(
        color: const Color(0xFFF7F7F7),
        child: Center(child: Text(_loadError, textAlign: TextAlign.center)),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Color(0xFFF7F7F7),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: platformController,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }
}
