import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/app.dart';
import 'package:hilla_ride/core/config/app_variant.dart';
import 'package:hilla_ride/core/config/firebase_config.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/firebase_options.dart';
import 'package:provider/provider.dart';

Future<void> bootstrapApp(AppVariant variant) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.variant = variant;

  var firebaseReady = false;
  var firebaseError = '';

  try {
    if (!FirebaseConfig.isConfigured) {
      firebaseError =
          'Firebase is not linked yet. Run flutterfire configure in the project folder.';
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
    }
  } catch (error, stackTrace) {
    firebaseError = error.toString();
    debugPrint('Firebase.initializeApp failed: $error\n$stackTrace');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState.create()),
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: HillaRideApp(
        variant: variant,
        firebaseReady: firebaseReady,
        firebaseError: firebaseError,
      ),
    ),
  );

  if (firebaseReady && !AppConfig.variant.isWebAdmin) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          await NotificationService.initialize();
        } catch (error, stackTrace) {
          debugPrint(
            'NotificationService.initialize failed: $error\n$stackTrace',
          );
        }
      }());
    });
  }
}
