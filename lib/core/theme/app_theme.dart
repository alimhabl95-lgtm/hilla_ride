import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';

class AppTheme {
  AppTheme._();

  static const _iconTheme = IconThemeData(color: Colors.white);
  static const _bodyIconTheme = IconThemeData(color: AppBrandAssets.brandNavy);

  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppBrandAssets.brandTeal,
      onPrimary: Colors.white,
      secondary: AppBrandAssets.brandGold,
      onSecondary: AppBrandAssets.brandNavy,
      tertiary: AppBrandAssets.brandTealDark,
      onTertiary: Colors.white,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: AppBrandAssets.brandNavy,
      surfaceContainerHighest: Color(0xFFE8F7F5),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppBrandAssets.brandSurface,
      iconTheme: _bodyIconTheme,
      primaryIconTheme: _iconTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppBrandAssets.brandTeal,
        foregroundColor: Colors.white,
        iconTheme: _iconTheme,
        actionsIconTheme: _iconTheme,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: AppBrandAssets.brandTeal.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppBrandAssets.brandTeal.withValues(alpha: 0.12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppBrandAssets.brandTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBrandAssets.brandTealDark,
          side: const BorderSide(color: AppBrandAssets.brandTeal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppBrandAssets.brandGold,
        foregroundColor: AppBrandAssets.brandNavy,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppBrandAssets.brandTeal, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppBrandAssets.brandTeal.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: AppBrandAssets.brandNavy),
      ),
    );

    final textTheme = base.textTheme.apply(
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Noto Naskh Arabic', 'sans-serif'],
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
