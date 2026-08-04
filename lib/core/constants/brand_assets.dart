import 'package:flutter/material.dart';

class AppBrandAssets {
  AppBrandAssets._();

  static const logo = 'assets/images/app_logo.png';

  // Mockup-aligned Hello Tuk-Tuk palette
  static const brandTeal = Color(0xFF00B3A6);
  static const brandTealDark = Color(0xFF0E948C);
  static const brandGold = Color(0xFFF8B728);
  static const brandGoldDark = Color(0xFFE6A800);
  static const brandNavy = Color(0xFF111827);
  static const brandBlack = Color(0xFF111111);
  static const brandSurface = Color(0xFFF3F4F6);
  static const brandMuted = Color(0xFF6B7280);
  static const brandSuccess = Color(0xFF16A34A);
  static const brandWarning = Color(0xFFF59E0B);
  static const brandDanger = Color(0xFFDC2626);
  static const brandBorder = Color(0xFFE5E7EB);
}

/// Spacing, radii, and elevation used across Customer + Driver UI.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadii {
  AppRadii._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: AppBrandAssets.brandNavy.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppBrandAssets.brandNavy.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
