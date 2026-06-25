import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';

/// Vector tuk-tuk mascot with driving bounce, spinning wheels, and a waving hand.
class AnimatedTukTuk extends StatelessWidget {
  const AnimatedTukTuk({
    super.key,
    required this.width,
    required this.animationTime,
    this.showHand = true,
    this.canopyColor,
    this.bodyColor,
    this.wheelColor,
  });

  final double width;
  final double animationTime;
  final bool showHand;
  final Color? canopyColor;
  final Color? bodyColor;
  final Color? wheelColor;

  @override
  Widget build(BuildContext context) {
    final height = width * 0.82;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TukTukPainter(
          animationTime: animationTime,
          showHand: showHand,
          canopyColor: canopyColor,
          bodyColor: bodyColor,
          wheelColor: wheelColor,
        ),
        size: Size(width, height),
      ),
    );
  }
}

/// Compact static tuk-tuk for mode tiles and list icons.
class TukTukTileIcon extends StatelessWidget {
  const TukTukTileIcon({
    super.key,
    this.size = 40,
    this.accentColor = AppBrandAssets.brandTealDark,
  });

  final double size;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedTukTuk(
      width: size,
      animationTime: 0,
      showHand: false,
      canopyColor: AppBrandAssets.brandGold,
      bodyColor: accentColor,
      wheelColor: accentColor.withValues(alpha: 0.85),
    );
  }
}

class _TukTukPainter extends CustomPainter {
  _TukTukPainter({
    required this.animationTime,
    this.showHand = true,
    this.canopyColor,
    this.bodyColor,
    this.wheelColor,
  });

  final double animationTime;
  final bool showHand;
  final Color? canopyColor;
  final Color? bodyColor;
  final Color? wheelColor;

  static const _bodyOrange = Color(0xFFFF7A1A);
  static const _bodyTeal = AppBrandAssets.brandTeal;

  Color get _canopy => canopyColor ?? _bodyOrange;
  Color get _body => bodyColor ?? _bodyTeal;
  Color get _wheel => wheelColor ?? _bodyOrange;

  @override
  void paint(Canvas canvas, Size size) {
    final bounce = math.sin(animationTime * math.pi * 2 * 3.2) * size.height * 0.018;
    final tilt = math.sin(animationTime * math.pi * 2 * 3.2) * 0.018;

    canvas.save();
    canvas.translate(0, bounce);
    canvas.translate(size.width * 0.5, size.height * 0.92);
    canvas.rotate(tilt);
    canvas.translate(-size.width * 0.5, -size.height * 0.92);

    _drawShadow(canvas, size);
    _drawWheels(canvas, size);
    _drawBody(canvas, size);
    if (showHand) {
      _drawHand(canvas, size);
    }

    canvas.restore();
  }

  void _drawShadow(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = AppBrandAssets.brandNavy.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.94),
        width: size.width * 0.72,
        height: size.height * 0.08,
      ),
      shadow,
    );
  }

  void _drawWheels(Canvas canvas, Size size) {
    final wheelRadius = size.width * 0.11;
    final centers = [
      Offset(size.width * 0.24, size.height * 0.82),
      Offset(size.width * 0.74, size.height * 0.82),
    ];

    for (final center in centers) {
      _drawWheel(canvas, center, wheelRadius);
    }
  }

  void _drawWheel(Canvas canvas, Offset center, double radius) {
    final rotation = animationTime * math.pi * 2 * 5.5;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = _wheel,
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.58,
      Paint()..color = Colors.white,
    );

    final spokePaint = Paint()
      ..color = _wheel.withValues(alpha: 0.35)
      ..strokeWidth = radius * 0.12
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * radius * 0.48, math.sin(angle) * radius * 0.48),
        spokePaint,
      );
    }

    canvas.restore();
  }

  void _drawBody(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final tealBody = Path()
      ..moveTo(w * 0.08, h * 0.72)
      ..quadraticBezierTo(w * 0.04, h * 0.58, w * 0.16, h * 0.5)
      ..lineTo(w * 0.88, h * 0.5)
      ..quadraticBezierTo(w * 0.98, h * 0.56, w * 0.96, h * 0.72)
      ..quadraticBezierTo(w * 0.94, h * 0.84, w * 0.82, h * 0.84)
      ..lineTo(w * 0.18, h * 0.84)
      ..quadraticBezierTo(w * 0.06, h * 0.84, w * 0.08, h * 0.72)
      ..close();

    canvas.drawPath(tealBody, Paint()..color = _body);

    final orangeCanopy = Path()
      ..moveTo(w * 0.14, h * 0.52)
      ..lineTo(w * 0.9, h * 0.52)
      ..quadraticBezierTo(w * 0.98, h * 0.52, w * 0.98, h * 0.42)
      ..lineTo(w * 0.98, h * 0.24)
      ..quadraticBezierTo(w * 0.98, h * 0.14, w * 0.88, h * 0.14)
      ..lineTo(w * 0.22, h * 0.14)
      ..quadraticBezierTo(w * 0.1, h * 0.14, w * 0.1, h * 0.28)
      ..lineTo(w * 0.1, h * 0.42)
      ..quadraticBezierTo(w * 0.1, h * 0.52, w * 0.14, h * 0.52)
      ..close();

    canvas.drawPath(orangeCanopy, Paint()..color = _canopy);

    final cabin = Path()
      ..moveTo(w * 0.18, h * 0.5)
      ..lineTo(w * 0.82, h * 0.5)
      ..lineTo(w * 0.76, h * 0.72)
      ..quadraticBezierTo(w * 0.74, h * 0.78, w * 0.66, h * 0.78)
      ..lineTo(w * 0.34, h * 0.78)
      ..quadraticBezierTo(w * 0.26, h * 0.78, w * 0.24, h * 0.72)
      ..close();

    canvas.drawPath(cabin, Paint()..color = Colors.white);

    final seat = Path()
      ..moveTo(w * 0.34, h * 0.58)
      ..quadraticBezierTo(w * 0.5, h * 0.52, w * 0.66, h * 0.58)
      ..lineTo(w * 0.62, h * 0.7)
      ..lineTo(w * 0.38, h * 0.7)
      ..close();

    canvas.drawPath(
      seat,
      Paint()..color = _body.withValues(alpha: 0.18),
    );
  }

  void _drawHand(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final handCenter = Offset(w * 0.52, h * 0.08);
    final waveAngle = math.sin(animationTime * math.pi * 2 * 2.8) * 0.42;
    final pulse = (math.sin(animationTime * math.pi * 2 * 2.8) + 1) / 2;

    canvas.save();
    canvas.translate(handCenter.dx, handCenter.dy);
    canvas.rotate(waveAngle);

    _drawWaveArcs(canvas, pulse);

    final hand = Path()
      ..moveTo(-w * 0.02, h * 0.04)
      ..quadraticBezierTo(-w * 0.04, h * 0.01, -w * 0.02, -h * 0.02)
      ..lineTo(-w * 0.015, -h * 0.07)
      ..quadraticBezierTo(-w * 0.012, -h * 0.1, -w * 0.008, -h * 0.07)
      ..lineTo(-w * 0.004, -h * 0.02)
      ..quadraticBezierTo(-w * 0.002, -h * 0.1, w * 0.002, -h * 0.07)
      ..lineTo(w * 0.006, -h * 0.02)
      ..quadraticBezierTo(w * 0.008, -h * 0.1, w * 0.012, -h * 0.07)
      ..lineTo(w * 0.016, -h * 0.02)
      ..quadraticBezierTo(w * 0.018, -h * 0.1, w * 0.022, -h * 0.07)
      ..lineTo(w * 0.026, -h * 0.02)
      ..quadraticBezierTo(w * 0.03, -h * 0.09, w * 0.034, -h * 0.06)
      ..lineTo(w * 0.038, h * 0.01)
      ..quadraticBezierTo(w * 0.04, h * 0.05, w * 0.02, h * 0.05)
      ..quadraticBezierTo(w * 0.0, h * 0.05, -w * 0.02, h * 0.04)
      ..close();

    canvas.drawPath(hand, Paint()..color = AppBrandAssets.brandNavy);

    canvas.restore();
  }

  void _drawWaveArcs(Canvas canvas, double pulse) {
    final paint = Paint()
      ..color = AppBrandAssets.brandNavy.withValues(alpha: 0.25 + pulse * 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final leftArc = Path()
      ..moveTo(-18, 2)
      ..quadraticBezierTo(-26, -8, -16, -16);
    final rightArc = Path()
      ..moveTo(18, 2)
      ..quadraticBezierTo(26, -8, 16, -16);

    canvas.drawPath(leftArc, paint);
    canvas.drawPath(rightArc, paint);
  }

  @override
  bool shouldRepaint(covariant _TukTukPainter oldDelegate) {
    return oldDelegate.animationTime != animationTime ||
        oldDelegate.showHand != showHand ||
        oldDelegate.canopyColor != canopyColor ||
        oldDelegate.bodyColor != bodyColor ||
        oldDelegate.wheelColor != wheelColor;
  }
}
