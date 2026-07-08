import 'package:cloud_firestore/cloud_firestore.dart';

class RideNumberService {
  RideNumberService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _counterDoc = 'config/ride_counter';
  static const _startingNumber = 100001;

  Future<String> allocateRideNumber() async {
    final ref = _firestore.doc(_counterDoc);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final next = (snapshot.data()?['nextNumber'] as num?)?.toInt() ??
          _startingNumber;
      transaction.set(
        ref,
        {
          'nextNumber': next + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return next.toString();
    });
  }
}
