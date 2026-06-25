import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/promo_models.dart';

class PromoService {
  PromoService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _promoRef(String code) =>
      _firestore.collection('config').doc('promo_$code');

  Stream<PromoCodeConfig> watchPromoCode(String code) {
    return _promoRef(code).snapshots().map(
          (snapshot) => PromoCodeConfig.fromMap(snapshot.data()),
        );
  }

  Future<PromoCodeConfig> getPromoCode(String code) async {
    try {
      final snapshot = await _promoRef(code).get();
      if (!snapshot.exists || snapshot.data() == null) {
        if (code == 'FREE3') {
          await ensureFree3Exists();
          return PromoCodeConfig.free3Defaults;
        }
        return PromoCodeConfig.free3Defaults;
      }
      return PromoCodeConfig.fromMap(snapshot.data());
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return PromoCodeConfig.free3Defaults;
      }
      rethrow;
    }
  }

  Future<void> ensureFree3Exists() async {
    try {
      final snapshot = await _promoRef('FREE3').get();
      if (snapshot.exists) return;
      await savePromoCode(PromoCodeConfig.free3Defaults);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }
  }

  Future<void> savePromoCode(PromoCodeConfig config) async {
    final payload = config.toMap();
    final docPayload = {
      ...payload,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _promoRef(config.code).set(docPayload);
      return;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      if (kDebugMode) {
        debugPrint(
          'Promo Firestore write denied, trying savePromoConfig function.',
        );
      }
    }

    try {
      final callable = _functions.httpsCallable('savePromoConfig');
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'savePromoConfig function failed: ${error.code} ${error.message}',
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> signupPromoFields(PromoCodeConfig config) {
    if (!config.enabled || !config.autoAssignOnSignup) return const {};
    return {
      'promoCode': config.code,
      'promoRidesUsed': 0,
      'promoRidesLimit': config.maxRides,
    };
  }

  PromoApplication applyPromo({
    required AppUser user,
    required PromoCodeConfig config,
    required int baseFareIqd,
  }) {
    if (baseFareIqd <= 0) {
      return PromoApplication(
        baseFareIqd: baseFareIqd,
        discountIqd: 0,
        finalFareIqd: baseFareIqd,
      );
    }

    if (!config.enabled ||
        user.promoCode != config.code ||
        user.promoRidesUsed >= user.promoRidesLimit) {
      return PromoApplication(
        baseFareIqd: baseFareIqd,
        discountIqd: 0,
        finalFareIqd: baseFareIqd,
      );
    }

    final rawDiscount = (baseFareIqd * config.discountPercent / 100).round();
    final discount = rawDiscount.clamp(0, config.maxDiscountIqd);
    final finalFare = (baseFareIqd - discount).clamp(0, baseFareIqd);

    return PromoApplication(
      baseFareIqd: baseFareIqd,
      discountIqd: discount,
      finalFareIqd: finalFare,
      promoCode: config.code,
    );
  }

  Future<void> consumePromoRide({
    required String customerId,
    required String promoCode,
  }) async {
    if (customerId.isEmpty || promoCode.isEmpty) return;

    final userRef = _firestore.collection('users').doc(customerId);
    final snapshot = await userRef.get();
    final data = snapshot.data();
    if (data == null) return;
    if (data['promoCode'] != promoCode) return;

    await userRef.update({
      'promoRidesUsed': FieldValue.increment(1),
    });
  }
}
