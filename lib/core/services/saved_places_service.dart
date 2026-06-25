import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hilla_ride/core/models/app_models.dart';

/// Stores a customer's favourite locations under
/// `users/{uid}/saved_places/{placeId}`.
class SavedPlacesService {
  SavedPlacesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_places');
  }

  Stream<List<SavedPlace>> watchSavedPlaces(String uid) {
    return _collection(uid).snapshots().map((snapshot) {
      final places = snapshot.docs
          .map((doc) => SavedPlace.fromMap(doc.id, doc.data()))
          .toList();
      places.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return places;
    });
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
  }) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Label is required');
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
}
