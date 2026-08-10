import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:uuid/uuid.dart';

class WalletService {
  WalletService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  Stream<WalletConfig> watchConfig() {
    return _firestore.collection('config').doc('wallet').snapshots().map(
          (doc) => WalletConfig.fromMap(doc.data()),
        );
  }

  Future<WalletConfig> fetchConfig() async {
    final doc = await _firestore.collection('config').doc('wallet').get();
    return WalletConfig.fromMap(doc.data());
  }

  Stream<List<WalletLedgerEntry>> watchLedger(String driverId, {int limit = 50}) {
    return _firestore
        .collection('walletLedger')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(WalletLedgerEntry.fromDoc).toList(),
        );
  }

  Stream<List<WalletRechargeRequest>> watchMyRechargeRequests(String driverId) {
    return _firestore
        .collection('walletRechargeRequests')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snap) => snap.docs.map(WalletRechargeRequest.fromDoc).toList(),
        );
  }

  Stream<List<WalletRechargeRequest>> watchPendingRechargeRequests() {
    return _firestore
        .collection('walletRechargeRequests')
        .where('status', isEqualTo: WalletRechargeStatus.pending.value)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs.map(WalletRechargeRequest.fromDoc).toList(),
        );
  }

  Future<String> uploadRechargeScreenshot({
    required String driverId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final id = const Uuid().v4();
    final ref = _storage
        .ref()
        .child('wallet_recharges')
        .child(driverId)
        .child('$id.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  Future<void> submitRechargeRequest({
    required int amountIqd,
    required WalletRechargeMethod method,
    required String screenshotUrl,
    String referenceNumber = '',
    String notes = '',
  }) async {
    await _functions.httpsCallable('submitWalletRechargeRequest').call({
      'amountIqd': amountIqd,
      'method': method.value,
      'screenshotUrl': screenshotUrl,
      'referenceNumber': referenceNumber.trim(),
      'notes': notes.trim(),
    });
  }

  Stream<List<WalletLedgerEntry>> watchRecentLedger({int limit = 500}) {
    return _firestore
        .collection('walletLedger')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(WalletLedgerEntry.fromDoc).toList(),
        );
  }

  Future<void> reviewRechargeRequest({
    required String requestId,
    required bool approve,
    String rejectionReason = '',
    int? approvedAmountIqd,
  }) async {
    await _functions.httpsCallable('reviewWalletRechargeRequest').call({
      'requestId': requestId,
      'approve': approve,
      'rejectionReason': rejectionReason.trim(),
      if (approvedAmountIqd != null) 'approvedAmountIqd': approvedAmountIqd,
    });
  }

  Future<void> adjustWallet({
    required String driverId,
    required int amountIqd,
    required String note,
  }) async {
    await _functions.httpsCallable('adjustDriverWallet').call({
      'driverId': driverId,
      'amountIqd': amountIqd,
      'note': note.trim(),
    });
  }

  Future<void> saveConfig(WalletConfig config) async {
    await _functions.httpsCallable('saveWalletConfig').call(config.toMap());
  }

  /// Backfill `walletBalanceIqd` / `walletStatus` on drivers missing them.
  Future<({int updated, int total})> ensureDriverWallets() async {
    final result =
        await _functions.httpsCallable('ensureDriverWallets').call();
    final data = Map<String, dynamic>.from(result.data as Map? ?? {});
    return (
      updated: (data['updated'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }
}
