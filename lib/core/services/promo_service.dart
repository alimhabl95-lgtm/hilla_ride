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
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _promoRef(String code) =>
      _firestore.collection('config').doc('promo_$code');

  Stream<PromoCodeConfig> watchPromoCode(String code) {
    return _promoRef(code).snapshots().map(
          (snapshot) => PromoCodeConfig.fromMap(snapshot.data()),
        );
  }

  Stream<List<PromoCodeConfig>> watchAllPromoCodes() {
    return _firestore.collection('config').snapshots().map((snapshot) {
      final configs = snapshot.docs
          .where((doc) => doc.id.startsWith('promo_'))
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data.putIfAbsent(
              'code',
              () => doc.id.replaceFirst('promo_', ''),
            );
            return PromoCodeConfig.fromMap(data);
          })
          .toList();
      configs.sort((a, b) => a.code.compareTo(b.code));
      return configs;
    });
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
    if (config.isExpired || config.isRedemptionLimitReached) return const {};
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
    String districtId = '',
    String promoKind = 'ride',
    int customerCompletedRides = 0,
  }) {
    if (baseFareIqd <= 0) {
      return PromoApplication(
        baseFareIqd: baseFareIqd,
        discountIqd: 0,
        finalFareIqd: baseFareIqd,
      );
    }

    final kindAllowed = config.kind == 'both' || config.kind == promoKind;
    final districtAllowed = config.districtIds.isEmpty ||
        (districtId.isNotEmpty && config.districtIds.contains(districtId));
    final eligibilityOk =
        customerCompletedRides >= config.minCompletedRidesForEligibility;

    if (!config.enabled ||
        config.isExpired ||
        config.isRedemptionLimitReached ||
        !kindAllowed ||
        !districtAllowed ||
        !eligibilityOk ||
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

    await _promoRef(promoCode).set(
      {'currentRedemptions': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  DocumentReference<Map<String, dynamic>> get _loyaltyRef =>
      _firestore.collection('config').doc('loyalty');

  Stream<LoyaltyConfig> watchLoyaltyConfig() {
    return _loyaltyRef.snapshots().map(
          (snapshot) => LoyaltyConfig.fromMap(snapshot.data()),
        );
  }

  Future<LoyaltyConfig> getLoyaltyConfig() async {
    final snapshot = await _loyaltyRef.get();
    return LoyaltyConfig.fromMap(snapshot.data());
  }

  Future<void> saveLoyaltyConfig(LoyaltyConfig config) async {
    await _functions.httpsCallable('saveLoyaltyConfig').call(config.toMap());
  }
}
