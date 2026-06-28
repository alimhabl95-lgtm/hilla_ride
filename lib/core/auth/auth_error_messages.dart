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

String functionsErrorMessage(FirebaseFunctionsException error, AppLocalizations l10n) {
  switch (error.code) {
    case 'already-exists':
      return l10n.authEmailAlreadyInUse;
    case 'not-found':
      return l10n.loginFailed;
    case 'invalid-argument':
      return error.message ?? l10n.signupFailed;
    case 'unavailable':
      return l10n.authNetworkError;
    case 'internal':
    default:
      return error.message ?? l10n.signupFailed;
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
      return FirebaseAuthException(
        code: 'internal',
        message: error.message,
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
