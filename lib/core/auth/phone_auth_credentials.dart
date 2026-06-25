import 'package:hilla_ride/core/constants/hilla_constants.dart';

/// Maps Iraqi phone numbers to Firebase Auth email identifiers (no OTP).
class PhoneAuthCredentials {
  PhoneAuthCredentials._();

  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('964')) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '${HillaConstants.defaultCountryCode}$digits';
  }

  static String toAuthEmail(String phoneE164) {
    final digits = phoneE164.replaceAll(RegExp(r'\D'), '');
    return '$digits@hello-tiktok.app';
  }

  static bool isValidPassword(String password) => password.length >= 6;

  static bool isValidIraqiPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('964')) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return RegExp(r'^7\d{9}$').hasMatch(digits);
  }
}
