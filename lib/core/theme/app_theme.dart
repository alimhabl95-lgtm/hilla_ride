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
      error: AppBrandAssets.brandDanger,
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
      dividerColor: AppBrandAssets.brandBorder,
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
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: AppBrandAssets.brandNavy.withValues(alpha: 0.08),
        indicatorColor: AppBrandAssets.brandTeal.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppBrandAssets.brandTealDark
                : AppBrandAssets.brandMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppBrandAssets.brandTealDark
                : AppBrandAssets.brandMuted,
            size: 24,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppBrandAssets.brandBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppBrandAssets.brandTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          foregroundColor: AppBrandAssets.brandTealDark,
          side: const BorderSide(color: AppBrandAssets.brandTeal, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.white,
        foregroundColor: AppBrandAssets.brandTealDark,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppBrandAssets.brandTeal, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppBrandAssets.brandBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppBrandAssets.brandBorder),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
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
      bodyColor: AppBrandAssets.brandNavy,
      displayColor: AppBrandAssets.brandNavy,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.35),
      ),
      primaryTextTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
