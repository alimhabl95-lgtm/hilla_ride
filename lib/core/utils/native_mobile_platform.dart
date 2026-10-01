import 'package:flutter/foundation.dart';

/// True on Android and iOS device builds (not web).
bool get isNativeMobileApp {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}
