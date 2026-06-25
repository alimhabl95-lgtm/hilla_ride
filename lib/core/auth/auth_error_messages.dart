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
