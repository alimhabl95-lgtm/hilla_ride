import 'package:firebase_core/firebase_core.dart';
import 'package:hilla_ride/firebase_options.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static bool get isConfigured {
    final options = DefaultFirebaseOptions.currentPlatform;
    return options.apiKey != 'REPLACE_ME' &&
        options.appId != 'REPLACE_ME' &&
        options.messagingSenderId != 'REPLACE_ME';
  }

  /// Safe init for Android/iOS where the native Google Services plugin may
  /// already have created the `[DEFAULT]` Firebase app.
  static Future<FirebaseApp> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return Firebase.app();
    }
    try {
      return await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app' && Firebase.apps.isNotEmpty) {
        return Firebase.app();
      }
      rethrow;
    }
  }
}
