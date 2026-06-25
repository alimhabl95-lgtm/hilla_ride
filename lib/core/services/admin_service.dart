import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/hilla_constants.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/utils/geohash.dart';
import 'package:uuid/uuid.dart';

class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<DriverProfile>> watchAllDrivers({int limit = 1000}) {
    return _firestore
        .collection('drivers')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverProfile.fromMap(doc.id, doc.data()))
          .where((driver) => !driver.isRemoved)
          .toList();
    });
  }

  Stream<List<Ride>> watchActiveRides({int limit = 150}) {
    return _firestore
        .collection('rides')
        .where('status', whereIn: [
          RideStatus.searching.value,
          RideStatus.matched.value,
          RideStatus.accepted.value,
          RideStatus.inProgress.value,
          RideStatus.awaitingCashPayment.value,
        ])
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs
          .map((doc) => Ride.fromMap(doc.id, doc.data()))
          .toList();
      rides.sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));
      return rides;
    });
  }

  Stream<List<Ride>> watchRecentRides({int limit = 50}) {
    return _firestore
        .collection('rides')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ride.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<List<Ride>> watchRidesByStatus(
    RideStatus status, {
    int limit = 40,
  }) {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: status.value)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ride.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<List<Ride>> watchRidesForDriver(String driverId) {
    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs
          .map((doc) => Ride.fromMap(doc.id, doc.data()))
          .toList();
      rides.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return rides;
    });
  }

  Stream<List<AppUser>> watchCustomers({int limit = 1000}) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.customer.value)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    });
  }

  Future<void> setCustomerBlocked({
    required String userId,
    required bool blocked,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'isBlocked': blocked,
      'blockedAt': blocked ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Future<DriverProfile?> getDriver(String uid) async {
    final doc = await _firestore.collection('drivers').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return DriverProfile.fromMap(doc.id, doc.data()!);
  }

  Stream<DriverProfile?> watchDriver(String driverId) {
    return _firestore.collection('drivers').doc(driverId).snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return DriverProfile.fromMap(snapshot.id, snapshot.data()!);
      },
    );
  }

  Future<void> markProfitsReceived({
    required String driverId,
    required String receivedByUid,
  }) async {
    final ref = _firestore.collection('drivers').doc(driverId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('driver_not_found');
      }

      final data = snapshot.data()!;
      final outstanding = data.containsKey('outstandingPlatformCommissionIqd')
          ? (data['outstandingPlatformCommissionIqd'] as num?)?.toInt() ?? 0
          : (data['totalPlatformCommissionIqd'] as num?)?.toInt() ?? 0;
      if (outstanding <= 0) return;

      final settlementRef = ref.collection('profit_settlements').doc();
      transaction.set(settlementRef, {
        'amountIqd': outstanding,
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedBy': receivedByUid,
      });
      transaction.update(ref, {
        'outstandingPlatformCommissionIqd': 0,
        'lastProfitReceivedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<DriverBonus>> watchAllDriverBonuses({int limit = 100}) {
    return _firestore
        .collectionGroup('bonuses')
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final bonuses = snapshot.docs.map((doc) {
        return DriverBonus.fromMap(
          doc.id,
          doc.reference.parent.parent?.id ?? '',
          doc.data(),
        );
      }).toList();
      bonuses.sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
      return bonuses;
    });
  }

  Future<void> grantDriverBonus({
    required String driverId,
    required int amountIqd,
    required String reason,
    required String grantedByUid,
  }) async {
    if (amountIqd <= 0) {
      throw ArgumentError.value(amountIqd, 'amountIqd', 'Must be positive');
    }

    final driverRef = _firestore.collection('drivers').doc(driverId);
    final bonusRef = driverRef.collection('bonuses').doc();
    final batch = _firestore.batch();

    batch.set(bonusRef, {
      'amountIqd': amountIqd,
      'reason': reason.trim(),
      'createdBy': grantedByUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isPaid': false,
    });
    batch.update(driverRef, {
      'pendingBonusIqd': FieldValue.increment(amountIqd),
      'totalBonusGrantedIqd': FieldValue.increment(amountIqd),
    });

    await batch.commit();
  }

  Future<void> markBonusPaid({
    required String driverId,
    required String bonusId,
  }) async {
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final bonusRef = driverRef.collection('bonuses').doc(bonusId);

    await _firestore.runTransaction((transaction) async {
      final bonusSnap = await transaction.get(bonusRef);
      if (!bonusSnap.exists || bonusSnap.data() == null) {
        throw StateError('bonus_not_found');
      }

      final data = bonusSnap.data()!;
      if (data['isPaid'] as bool? ?? false) return;

      final amount = (data['amountIqd'] as num?)?.toInt() ?? 0;
      transaction.update(bonusRef, {
        'isPaid': true,
        'paidAt': FieldValue.serverTimestamp(),
      });
      transaction.update(driverRef, {
        'pendingBonusIqd': FieldValue.increment(-amount),
      });
    });
  }

  Stream<List<Ride>> watchDriverReviews({int limit = 100}) {
    return _firestore
        .collection('rides')
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Ride.fromMap(doc.id, doc.data()))
          .where((ride) => ride.driverRating != null)
          .toList();
    });
  }

  Stream<List<DriverProfile>> watchOnlineDrivers() {
    return _firestore
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverProfile.fromMap(doc.id, doc.data()))
          .where(
            (driver) =>
                driver.isApproved && !driver.isBlocked && !driver.isRemoved,
          )
          .toList();
    });
  }

  Future<void> deleteUserAccount(String userId) async {
    final callable = _functions.httpsCallable('deleteUserAccount');
    await callable.call({'userId': userId});
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> ref) async {
    while (true) {
      final snapshot = await ref.limit(200).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteDriverLocally(String driverId) async {
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final driverDoc = await driverRef.get();
    if (!driverDoc.exists) {
      throw StateError('driver_not_found');
    }

    await _deleteCollection(driverRef.collection('bonuses'));
    await _deleteCollection(driverRef.collection('profit_settlements'));
    await driverRef.delete();
  }

  Future<void> _deleteUserAccountLocally(String userId) async {
    if (userId.startsWith('fake_')) {
      await _deleteDriverLocally(userId);
      return;
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    if (!userDoc.exists || userDoc.data() == null) {
      throw StateError('account_not_found');
    }

    final data = userDoc.data()!;
    final role = data['role'] as String? ?? '';
    if (role == UserRole.manager.value || role == UserRole.assistant.value) {
      throw StateError('admin_account_protected');
    }

    final phone = (data['phone'] as String? ?? '').trim();

    try {
      await _deleteCollection(userRef.collection('saved_places'));
    } catch (_) {
      // Continue even if saved places cannot be listed/deleted.
    }

    try {
      final driverRef = _firestore.collection('drivers').doc(userId);
      if ((await driverRef.get()).exists) {
        await _deleteDriverLocally(userId);
      }
    } catch (_) {
      // Continue if driver cleanup fails; user profile removal is primary.
    }

    await userRef.delete();

    if (phone.isNotEmpty) {
      final phoneKey = phone.replaceAll(RegExp(r'\D'), '');
      await _firestore.collection('released_phones').doc(phoneKey).set({
        'phone': phone,
        'previousUid': userId,
        'releasedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> removeCustomer(String userId) => deleteUserAccount(userId);

  Future<void> removeDriver(String driverId) => deleteUserAccount(driverId);

  Future<DriverProfile> createFakeDriver({
    required String name,
    required String vehiclePlate,
    required String vehicleType,
    required String createdByUid,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name is required');
    }

    const uuid = Uuid();
    final driverId = 'fake_${uuid.v4()}';
    final ref = _firestore.collection('drivers').doc(driverId);
    final workDistrict = BabilRegions.customerDistrict;
    final workSub = workDistrict.subDistricts.first;
    final lat = workSub.center.latitude;
    final lng = workSub.center.longitude;
    final data = {
      'name': trimmedName,
      'phone': '',
      'vehicleType': vehicleType.trim().isEmpty ? 'Tuk-Tuk' : vehicleType.trim(),
      'vehiclePlate': vehiclePlate.trim(),
      'vehicleColor': '',
      'licenseNumber': 'FAKE',
      'approvalStatus': DriverApprovalStatus.approved.value,
      'isOnline': false,
      'isBlocked': false,
      'isRemoved': false,
      'isFakeDriver': true,
      'autoAcceptRides': true,
      'createdBy': createdByUid,
      'assignedDistrictId': workDistrict.id,
      'assignedSubDistrictId': workSub.id,
      'latitude': lat,
      'longitude': lng,
      'geohash': Geohash.encode(lat, lng),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'cancelledRidesCount': 0,
      'completedRidesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await ref.set(data);
    final snapshot = await ref.get();
    return DriverProfile.fromMap(driverId, snapshot.data()!);
  }

  Future<void> setFakeDriverOnline({
    required String driverId,
    required bool isOnline,
  }) async {
    final ref = _firestore.collection('drivers').doc(driverId);
    final snapshot = await ref.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('driver_not_found');
    }

    final data = snapshot.data()!;
    if ((data['isFakeDriver'] as bool?) != true) {
      throw StateError('not_fake_driver');
    }
    if (data['isRemoved'] as bool? ?? false) {
      throw StateError('removed');
    }
    if (data['isBlocked'] as bool? ?? false) {
      throw StateError('blocked');
    }

    if (isOnline) {
      final districtId = data['assignedDistrictId'] as String? ?? '';
      final subDistrictId = data['assignedSubDistrictId'] as String? ?? '';
      double lat = (data['latitude'] as num?)?.toDouble() ??
          HillaConstants.cityCenter.latitude;
      double lng = (data['longitude'] as num?)?.toDouble() ??
          HillaConstants.cityCenter.longitude;
      if (districtId.isNotEmpty) {
        final sub = BabilRegions.subDistrictById(
          districtId,
          subDistrictId.isNotEmpty
              ? subDistrictId
              : BabilRegions.districtById(districtId).subDistricts.first.id,
        );
        lat = sub.center.latitude;
        lng = sub.center.longitude;
      }
      await ref.update({
        'isOnline': true,
        'latitude': lat,
        'longitude': lng,
        'geohash': Geohash.encode(lat, lng),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'isOnline': false});
    }
  }

  Future<void> setDriverWorkDistrict({
    required String driverId,
    required String districtId,
    String? subDistrictId,
  }) async {
    final district = BabilRegions.districtById(districtId);
    final sub = subDistrictId == null || subDistrictId.isEmpty
        ? district.subDistricts.first
        : BabilRegions.subDistrictById(districtId, subDistrictId);
    final lat = sub.center.latitude;
    final lng = sub.center.longitude;

    await _firestore.collection('drivers').doc(driverId).update({
      'assignedDistrictId': district.id,
      'assignedSubDistrictId': sub.id,
      'latitude': lat,
      'longitude': lng,
      'geohash': Geohash.encode(lat, lng),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'hasActiveRide': false,
    });
  }
}
