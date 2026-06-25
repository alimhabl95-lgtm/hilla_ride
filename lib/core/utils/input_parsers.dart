import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

double? parseDecimalInput(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

int? parseIntInput(String raw) {
  final normalized = raw.trim().replaceAll(',', '').replaceAll('.', '');
  if (normalized.isEmpty) return null;
  return int.tryParse(normalized);
}

String pricingSaveErrorMessage({
  required String genericMessage,
  required String permissionMessage,
  Object? error,
}) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return permissionMessage;
  }
  if (error is FirebaseFunctionsException && error.code == 'permission-denied') {
    return permissionMessage;
  }
  if (error is FirebaseException && error.message?.isNotEmpty == true) {
    return '${genericMessage}\n${error.message}';
  }
  if (error is FirebaseFunctionsException && error.message?.isNotEmpty == true) {
    return '${genericMessage}\n${error.message}';
  }
  return genericMessage;
}

bool isFirestorePermissionDenied(Object? error) {
  return (error is FirebaseException && error.code == 'permission-denied') ||
      (error is FirebaseFunctionsException && error.code == 'permission-denied');
}
