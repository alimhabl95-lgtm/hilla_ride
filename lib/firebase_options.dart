import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Run `dart pub global activate flutterfire_cli` then `flutterfire configure`
/// to replace this file with your real Firebase project settings.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Hello tiktok supports Android and iOS only.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAsgktwgQMXi9i5majam_z3Yion1_0qqLY',
    appId: '1:862680507196:web:5f9ccfbf6773f893987439',
    messagingSenderId: '862680507196',
    projectId: 'hello-tiktok-57dc5',
    authDomain: 'hello-tiktok-57dc5.firebaseapp.com',
    storageBucket: 'hello-tiktok-57dc5.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyATkDQ-s_PdP3rbRnrvkLs4XXrIAdzE7Q0',
    appId: '1:862680507196:android:60e6335cb57b9e76987439',
    messagingSenderId: '862680507196',
    projectId: 'hello-tiktok-57dc5',
    storageBucket: 'hello-tiktok-57dc5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDD4PxDlgfhdKj-_Z7sCkWHZ0hrVRtD2aA',
    appId: '1:862680507196:ios:ff34cc182d7946bc987439',
    messagingSenderId: '862680507196',
    projectId: 'hello-tiktok-57dc5',
    storageBucket: 'hello-tiktok-57dc5.firebasestorage.app',
    iosBundleId: 'com.hillaride.hillaRide',
  );
}
