import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/core/constants/brand_assets.dart';
import 'package:hilla_ride/core/utils/native_mobile_platform.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Waze or Google Maps to a lat/lng on Android and iOS.
class AndroidWazeNavigation {
  AndroidWazeNavigation._();

  static bool get isSupported => isNativeMobileApp;

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<bool> start({
    required double latitude,
    required double longitude,
  }) async {
    if (!isSupported) return false;
    if (!_isValidCoordinate(latitude, longitude)) return false;

    if (await openWaze(latitude: latitude, longitude: longitude)) {
      return true;
    }
    return openGoogleMaps(latitude: latitude, longitude: longitude);
  }

  static Future<bool> openWaze({
    required double latitude,
    required double longitude,
  }) async {
    if (!isSupported || !_isValidCoordinate(latitude, longitude)) return false;
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    if (await _tryLaunch(Uri.parse('waze://?ll=$lat,$lng&navigate=yes'))) {
      return true;
    }
    return _tryLaunch(
      Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes'),
    );
  }

  static Future<bool> openGoogleMaps({
    required double latitude,
    required double longitude,
  }) async {
    if (!isSupported || !_isValidCoordinate(latitude, longitude)) return false;
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);

    if (_isIOS) {
      if (await _tryLaunch(
        Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'),
      )) {
        return true;
      }
      if (await _tryLaunch(Uri.parse('maps://?daddr=$lat,$lng'))) {
        return true;
      }
      return _tryLaunch(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        ),
      );
    }

    if (await _tryLaunch(Uri.parse('google.navigation:q=$lat,$lng&mode=d'))) {
      return true;
    }
    if (await _tryLaunch(Uri.parse('geo:$lat,$lng?q=$lat,$lng'))) {
      return true;
    }
    return _tryLaunch(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      ),
    );
  }

  /// Lets the customer pick Google Maps or Waze for the driver's live pin.
  static Future<void> showChooser(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) async {
    if (!isSupported || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                l10n.viewDriverOnMap,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppBrandAssets.brandNavy,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.map_outlined,
                color: AppBrandAssets.brandTealDark,
              ),
              title: Text(
                l10n.openInGoogleMaps,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(sheetContext).pop('google'),
            ),
            ListTile(
              leading: const Icon(
                Icons.navigation_outlined,
                color: AppBrandAssets.brandTealDark,
              ),
              title: Text(
                l10n.openInWaze,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(sheetContext).pop('waze'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;
    final opened = choice == 'waze'
        ? await openWaze(latitude: latitude, longitude: longitude)
        : await openGoogleMaps(latitude: latitude, longitude: longitude);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.navigationAppUnavailable)),
    );
  }

  static bool _isValidCoordinate(double latitude, double longitude) {
    if (latitude == 0 && longitude == 0) return false;
    return latitude.abs() <= 90 && longitude.abs() <= 180;
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
