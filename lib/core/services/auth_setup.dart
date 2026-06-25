import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Default test credentials — must match Firebase Console → Authentication →
/// Phone → Phone numbers for testing.
class AuthTestConfig {
  AuthTestConfig._();

  static const String testPhoneE164 = '+9647701234567';
  static const String testSmsCode = '123456';

  /// Add this in Firebase Console → Project settings → Android app → SHA-1.
  static const String androidDebugSha1 =
      'F9:1C:7E:B9:D2:D8:F3:36:A5:71:91:7D:88:D6:A1:8E:FA:E0:60:65';
}

Future<void> configureAuthForDevelopment() async {
  if (!kDebugMode) return;

  await FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: true,
    phoneNumber: AuthTestConfig.testPhoneE164,
    smsCode: AuthTestConfig.testSmsCode,
  );
}

String friendlyPhoneAuthError(FirebaseAuthException error) {
  final message = (error.message ?? '').toLowerCase();

  if (message.contains('sign-in provider is disabled') ||
      message.contains('operation is not allowed')) {
    return 'Enable Phone sign-in in Firebase Console → Authentication → Sign-in method → Phone.';
  }

  if (message.contains('region enabled')) {
    return 'Iraq SMS is blocked until enabled in Firebase, OR use the test number '
        '${AuthTestConfig.testPhoneE164} with code ${AuthTestConfig.testSmsCode} '
        '(add it under Authentication → Phone → Phone numbers for testing).';
  }

  if (message.contains('invalid app credential') ||
      message.contains('app verification')) {
    return 'Add your Android SHA-1 fingerprint in Firebase Console → Project settings '
        '→ Your Android app, then download google-services.json again.';
  }

  return error.message ?? 'Phone verification failed.';
}
