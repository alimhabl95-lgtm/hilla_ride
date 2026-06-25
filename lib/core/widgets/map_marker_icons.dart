import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerIcons {
  MapMarkerIcons._();

  static BitmapDescriptor? driver;
  static final _tripMarkerCache = <String, BitmapDescriptor>{};

  static const Color pickupColor = Color(0xFFFF9500);
  static const Color destinationColor = Color(0xFF007AFF);

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

  static Future<BitmapDescriptor> _buildDriverMarker() async {
    const size = 52.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = size / 2;

    canvas.drawCircle(
      Offset(center, center + 2),
      center * 0.78,
      Paint()..color = Colors.black26,
    );
    canvas.drawCircle(
      Offset(center, center),
      center * 0.78,
      Paint()..color = const Color(0xFF0284C7),
    );
    canvas.drawCircle(
      Offset(center, center),
      center * 0.78,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.05,
    );

    const icon = Icons.local_taxi_rounded;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.38,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center - textPainter.width / 2, center - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
