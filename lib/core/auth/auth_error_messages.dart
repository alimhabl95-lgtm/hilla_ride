import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hilla_ride/l10n/app_localizations.dart';

String authErrorMessage(FirebaseAuthException error, AppLocalizations l10n) {
  switch (error.code) {
    case 'operation-not-allowed':
      return l10n.authEmailPasswordDisabled;
    case 'email-already-in-use':
      return l10n.authEmailAlreadyInUse;
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-email':
      return l10n.loginFailed;
    case 'weak-password':
      return l10n.passwordMinLength;
    case 'too-many-requests':
      return l10n.authTooManyRequests;
    case 'network-request-failed':
      return l10n.authNetworkError;
    case 'session-active':
      return l10n.accountAlreadyOpenElsewhere;
    default:
      return error.message ?? l10n.signupFailed;
  }
}

String? extractFunctionsErrorMessage(FirebaseFunctionsException error) {
  final message = error.message?.trim();
  if (message != null &&
      message.isNotEmpty &&
      message.toLowerCase() != 'internal') {
    return message;
  }

  final details = error.details;
  if (details is String && details.trim().isNotEmpty) {
    return details.trim();
  }
  if (details is Map) {
    final nested = details['message'];
    if (nested is String && nested.trim().isNotEmpty) {
      return nested.trim();
    }
  }

  return null;
}

String functionsErrorMessage(FirebaseFunctionsException error, AppLocalizations l10n) {
  final message = extractFunctionsErrorMessage(error);
  if (message != null) {
    return message;
  }

  switch (error.code) {
    case 'already-exists':
      return l10n.authEmailAlreadyInUse;
    case 'not-found':
      return l10n.loginFailed;
    case 'invalid-argument':
      return l10n.signupFailed;
    case 'permission-denied':
    case 'failed-precondition':
      return l10n.removeDriverFailed;
    case 'unavailable':
      return l10n.authNetworkError;
    case 'internal':
    default:
      return l10n.signupFailed;
  }
}

String adminDeleteErrorMessage(
  FirebaseFunctionsException error,
  AppLocalizations l10n, {
  String? fallback,
}) {
  return extractFunctionsErrorMessage(error) ??
      fallback ??
      l10n.removeDriverFailed;
}

String assistantCreateErrorMessage(
  FirebaseFunctionsException error,
  AppLocalizations l10n,
) {
  final message = extractFunctionsErrorMessage(error);
  if (message != null) {
    return message;
  }

  switch (error.code) {
    case 'already-exists':
      return l10n.authEmailAlreadyInUse;
    case 'invalid-argument':
      return l10n.assistantFormInvalid;
    case 'permission-denied':
      return l10n.managerAccessDenied;
    case 'unauthenticated':
      return l10n.loginFailed;
    case 'failed-precondition':
      return extractFunctionsErrorMessage(error) ?? l10n.assistantCreateFailed;
    case 'internal':
      return extractFunctionsErrorMessage(error) ?? l10n.signupFailed;
    default:
      return extractFunctionsErrorMessage(error) ?? l10n.assistantCreateFailed;
  }
}

FirebaseAuthException authExceptionFromFunctions(FirebaseFunctionsException error) {
  switch (error.code) {
    case 'already-exists':
      return FirebaseAuthException(
        code: 'email-already-in-use',
        message: error.message,
      );
    case 'not-found':
      return FirebaseAuthException(
        code: 'user-not-found',
        message: error.message,
      );
    case 'invalid-argument':
      return FirebaseAuthException(
        code: error.message?.contains('Password') == true
            ? 'weak-password'
            : 'invalid-phone',
        message: error.message,
      );
    default:
      final message = extractFunctionsErrorMessage(error);
      return FirebaseAuthException(
        code: 'internal',
        message: message ?? 'Request failed. Check your internet and try again.',
      );
  }
}

void showAuthErrorSnackBar(
  BuildContext context,
  FirebaseAuthException error,
) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(authErrorMessage(error, l10n)),
      duration: const Duration(seconds: 6),
    ),
  );
}

void showFunctionsErrorSnackBar(
  BuildContext context,
  FirebaseFunctionsException error,
) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(functionsErrorMessage(error, l10n)),
      duration: const Duration(seconds: 6),
    ),
  );
}
