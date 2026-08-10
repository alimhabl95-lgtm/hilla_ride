import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hilla_ride/core/models/app_models.dart';

/// Stores a customer's favourite locations under
/// `users/{uid}/saved_places/{placeId}` and favorite businesses under
/// `users/{uid}/favorite_businesses/{businessId}`.
class SavedPlacesService {
  SavedPlacesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_places');
  }

  CollectionReference<Map<String, dynamic>> _favoriteBusinesses(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorite_businesses');
  }

  Stream<List<SavedPlace>> watchSavedPlaces(String uid) {
    return _collection(uid).snapshots().map((snapshot) {
      final places = snapshot.docs
          .map((doc) => SavedPlace.fromMap(doc.id, doc.data()))
          .toList();
      places.sort((a, b) {
        final typeOrder = a.placeType.index.compareTo(b.placeType.index);
        if (typeOrder != 0) return typeOrder;
        return (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
      return places;
    });
  }

  Stream<Set<String>> watchFavoriteBusinessIds(String uid) {
    return _favoriteBusinesses(uid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  Future<List<SavedPlace>> getSavedPlaces(String uid) async {
    final snapshot = await _collection(uid).get();
    final places = snapshot.docs
        .map((doc) => SavedPlace.fromMap(doc.id, doc.data()))
        .toList();
    places.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return places;
  }

  Future<SavedPlace> addSavedPlace({
    required String uid,
    required String label,
    required double latitude,
    required double longitude,
    SavedPlaceType placeType = SavedPlaceType.other,
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Label is required');
    }

    if (placeType == SavedPlaceType.home || placeType == SavedPlaceType.work) {
      final existing = await _collection(uid)
          .where('placeType', isEqualTo: placeType.value)
          .limit(1)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
      final ref = _collection(uid).doc(placeType.value);
      await ref.set({
        'label': trimmed,
        'latitude': latitude,
        'longitude': longitude,
        'placeType': placeType.value,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final snapshot = await ref.get();
      return SavedPlace.fromMap(ref.id, snapshot.data() ?? const {});
    }

    final existing = await _collection(uid)
        .where('latitude', isEqualTo: latitude)
        .where('longitude', isEqualTo: longitude)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      return SavedPlace.fromMap(doc.id, doc.data());
    }

    final ref = _collection(uid).doc();
    await ref.set({
      'label': trimmed,
      'latitude': latitude,
      'longitude': longitude,
      'placeType': placeType.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final snapshot = await ref.get();
    return SavedPlace.fromMap(ref.id, snapshot.data() ?? const {});
  }

  Future<void> deleteSavedPlace({
    required String uid,
    required String placeId,
  }) async {
    await _collection(uid).doc(placeId).delete();
  }

  Future<bool> toggleFavoriteBusiness({
    required String uid,
    required String businessId,
  }) async {
    final ref = _favoriteBusinesses(uid).doc(businessId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
      return false;
    }
    await ref.set({
      'businessId': businessId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<bool> isFavoriteBusiness({
    required String uid,
    required String businessId,
  }) async {
    final snap = await _favoriteBusinesses(uid).doc(businessId).get();
    return snap.exists;
  }
}
