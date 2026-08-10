import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:hilla_ride/core/models/app_config_models.dart';
import 'package:hilla_ride/core/models/app_models.dart';

class AppConfigService {
  AppConfigService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  static const _docPath = 'config/app';

  Stream<AppRemoteConfig> watchConfig() {
    return _firestore.doc(_docPath).snapshots().map(
          (snapshot) => AppRemoteConfig.fromMap(snapshot.data()),
        );
  }

  Future<AppRemoteConfig> getConfig() async {
    try {
      final snapshot = await _firestore.doc(_docPath).get();
      return AppRemoteConfig.fromMap(snapshot.data());
    } catch (_) {
      return AppRemoteConfig.defaults;
    }
  }

  Future<void> saveAppConfig(
    AppRemoteConfig config, {
    AppUser? adminUser,
  }) async {
    final payload = {
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _functions.httpsCallable('saveAppConfig').call(payload);
      return;
    } catch (error, stackTrace) {
      debugPrint('saveAppConfig callable failed: $error\n$stackTrace');
    }

    final canWriteDirect = adminUser != null &&
        (adminUser.isOwnerManager ||
            adminUser.hasAdminPermission('appSettings'));
    if (!canWriteDirect) {
      throw StateError('Unable to save app config.');
    }

    await _firestore.doc(_docPath).set(payload, SetOptions(merge: true));
  }

  Stream<List<Announcement>> watchActiveBanners(String audience) {
    return _firestore
        .collection('announcements')
        .where('audience', isEqualTo: audience)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Announcement.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      final bannerItems =
          items.where((item) => item.showAsBanner).take(5).toList();
      if (bannerItems.isNotEmpty) return bannerItems;
      return items.take(5).toList();
    });
  }
}
