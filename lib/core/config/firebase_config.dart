import 'package:hilla_ride/firebase_options.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static bool get isConfigured {
    final options = DefaultFirebaseOptions.currentPlatform;
    return options.apiKey != 'REPLACE_ME' &&
        options.appId != 'REPLACE_ME' &&
        options.messagingSenderId != 'REPLACE_ME';
  }
}
