import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hilla_ride/firebase_options.dart';
import 'package:http/http.dart' as http;

class PasswordResetUtils {
  PasswordResetUtils._();

  static String? parseOobCode(String linkOrUrl) {
    final uri = Uri.tryParse(linkOrUrl);
    if (uri == null) return null;

    final direct = uri.queryParameters['oobCode'];
    if (direct != null && direct.isNotEmpty) return direct;

    final nestedLink = uri.queryParameters['link'];
    if (nestedLink != null && nestedLink.isNotEmpty) {
      return parseOobCode(Uri.decodeComponent(nestedLink));
    }

    return null;
  }

  static Future<String> requestResetLinkForEmail(String email) async {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    final response = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey',
      ),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requestType': 'PASSWORD_RESET',
        'email': email.trim(),
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final error = body is Map ? body['error'] : null;
      final message = error is Map
          ? (error['message'] as String? ?? 'Password reset failed.')
          : 'Password reset failed.';
      throw FirebaseAuthException(code: 'reset-failed', message: message);
    }

    if (body is! Map<String, dynamic>) {
      throw FirebaseAuthException(
        code: 'reset-failed',
        message: 'Password reset failed.',
      );
    }

    final link = body['oobLink'] as String?;
    if (link == null || link.isEmpty) {
      throw FirebaseAuthException(
        code: 'reset-failed',
        message: 'Could not create password reset link.',
      );
    }
    return link;
  }
}
