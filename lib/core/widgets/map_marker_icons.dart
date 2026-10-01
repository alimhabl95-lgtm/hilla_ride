import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerIcons {
  MapMarkerIcons._();

  static BitmapDescriptor? driver;
  static final _tripMarkerCache = <String, BitmapDescriptor>{};

  static const Color pickupColor = Color(0xFFFF9500);
  static const Color destinationColor = Color(0xFF007AFF);

  /// Official Hello Tuk-Tuk driver marker asset (no status labels).
  static const String driverAssetPath = 'assets/images/tuk_tuk_map_marker.png';

  /// On-screen marker width in logical pixels. The source art is a large
  /// RGB PNG, so it is cropped and keyed before being drawn at this size.
  static const double driverMarkerLogicalWidth = 42;

  static Future<void> ensureLoaded() async {
    driver ??= await _buildDriverMarker();
  }

  static Future<BitmapDescriptor> tripMarker({
    required bool isPickup,
    required String label,
  }) async {
    await ensureLoaded();
    final trimmed = label.trim().isEmpty ? (isPickup ? 'A' : 'B') : label.trim();
    final cacheKey = '${isPickup ? 'p' : 'd'}|$trimmed';
    final cached = _tripMarkerCache[cacheKey];
    if (cached != null) return cached;

    final marker = await _buildTripMarker(
      isPickup: isPickup,
      label: _truncateLabel(trimmed),
    );
    _tripMarkerCache[cacheKey] = marker;
    return marker;
  }

  static String _truncateLabel(String value, {int maxChars = 22}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars - 1)}…';
  }

  static Future<BitmapDescriptor> _buildTripMarker({
    required bool isPickup,
    required String label,
  }) async {
    const labelHeight = 34.0;
    const labelPaddingH = 10.0;
    const labelPaddingV = 6.0;
    const pinSize = 28.0;
    const gap = 6.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    )..layout(maxWidth: 180);

    final labelWidth = textPainter.width + labelPaddingH * 2;
    final width = labelWidth > pinSize ? labelWidth : pinSize + 8;
    final height = labelHeight + gap + pinSize + 6;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final labelLeft = (width - labelWidth) / 2;
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelLeft, 0, labelWidth, labelHeight),
      const Radius.circular(8),
    );
    canvas.drawShadow(
      Path()..addRRect(labelRect),
      Colors.black26,
      3,
      false,
    );
    canvas.drawRRect(
      labelRect,
      Paint()..color = Colors.white,
    );
    textPainter.paint(
      canvas,
      Offset(labelLeft + labelPaddingH, labelPaddingV),
    );

    final pinCenterX = width / 2;
    final pinCenterY = labelHeight + gap + pinSize / 2;

    if (isPickup) {
      canvas.drawCircle(
        Offset(pinCenterX, pinCenterY),
        pinSize / 2 + 2,
        Paint()..color = Colors.black12,
      );
      canvas.drawCircle(
        Offset(pinCenterX, pinCenterY),
        pinSize / 2,
        Paint()..color = pickupColor,
      );
      canvas.drawCircle(
        Offset(pinCenterX, pinCenterY),
        pinSize / 5,
        Paint()..color = Colors.white,
      );
    } else {
      final squareRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pinCenterX, pinCenterY),
          width: pinSize,
          height: pinSize,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        squareRect,
        Paint()..color = Colors.black12,
      );
      canvas.drawRRect(
        squareRect,
        Paint()..color = destinationColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(pinCenterX, pinCenterY),
            width: pinSize / 3.2,
            height: pinSize / 3.2,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  /// Small transparent tuk-tuk. The source file is an opaque RGB PNG, so the
  /// white canvas is removed and the vehicle is cropped before it is drawn.
  static Future<BitmapDescriptor> _buildDriverMarker() async {
    final data = await rootBundle.load(driverAssetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final src = frame.image;
    final raw = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = src.width;
    final height = src.height;
    src.dispose();
    if (raw == null) {
      return BitmapDescriptor.defaultMarker;
    }

    final pixels = raw.buffer.asUint8List();
    var minX = width;
    var minY = height;
    var maxX = 0;
    var maxY = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final nearWhite = minC > 236 && (maxC - minC) < 22;
        if (nearWhite) {
          pixels[i + 3] = 0;
          continue;
        }
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX <= minX || maxY <= minY) {
      minX = 0;
      minY = 0;
      maxX = width - 1;
      maxY = height - 1;
    }

    final cropW = maxX - minX + 1;
    final cropH = maxY - minY + 1;
    const outW = 160;
    final outH = math.max(1, (outW * cropH / cropW).round());
    final keyed = await _imageFromRgba(pixels, width, height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      keyed,
      Rect.fromLTWH(
        minX.toDouble(),
        minY.toDouble(),
        cropW.toDouble(),
        cropH.toDouble(),
      ),
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    keyed.dispose();
    image.dispose();
    return BitmapDescriptor.bytes(
      png!.buffer.asUint8List(),
      width: driverMarkerLogicalWidth,
    );
  }

  static Future<ui.Image> _imageFromRgba(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
