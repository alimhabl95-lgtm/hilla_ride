import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:hilla_ride/core/services/commission_service.dart';
import 'package:hilla_ride/core/services/monthly_prize_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/services/pricing_service.dart';
import 'package:hilla_ride/core/services/promo_service.dart';
import 'package:hilla_ride/core/services/session_service.dart';
import 'package:hilla_ride/core/utils/geohash.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    SessionService? sessionService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _sessionService = sessionService ?? SessionService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final SessionService _sessionService;

  SessionService get sessionService => _sessionService;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _sessionService.clearSession(uid);
    }
    await _auth.signOut();
  }

  Future<UserCredential> signUpWithPhonePassword({
    required String phoneRaw,
    required String password,
    required String fullName,
    required UserRole role,
    String? email,
    int age = 18,
  }) async {
    if (!PhoneAuthCredentials.isValidPassword(password)) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters.',
      );
    }

    final phone = PhoneAuthCredentials.normalizePhone(phoneRaw);

    try {
      final callable = _functions.httpsCallable('registerWithPhonePassword');
      await callable.call({
        'phone': phone,
        'password': password,
        'fullName': fullName.trim(),
        'role': role.value,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'age': age,
      });
      return signInWithPhonePassword(
        phoneRaw: phoneRaw,
        password: password,
      );
    } on FirebaseFunctionsException catch (error) {
      throw authExceptionFromFunctions(error);
    }
  }

  Future<Map<String, dynamic>> _customerPromoFields() async {
    final promoService = PromoService();
    await promoService.ensureFree3Exists();
    final config = await promoService.getPromoCode('FREE3');
    return promoService.signupPromoFields(config);
  }

  Future<UserCredential> signInWithPhonePassword({
    required String phoneRaw,
    required String password,
  }) async {
    final phone = PhoneAuthCredentials.normalizePhone(phoneRaw);
    final authEmail = PhoneAuthCredentials.toAuthEmail(phone);
    final credential = await _auth.signInWithEmailAndPassword(
      email: authEmail,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid != null) {
      await _sessionService.claimSession(uid);
    }

    return credential;
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendPasswordResetForPhone(String phoneRaw) async {
    final phone = PhoneAuthCredentials.normalizePhone(phoneRaw);
    final snapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No account found for this phone number.',
      );
    }

    final authEmail = PhoneAuthCredentials.toAuthEmail(phone);
    await sendPasswordResetEmail(email: authEmail);
  }

  Future<String> requestPasswordResetLink(String phoneRaw) async {
    final phone = PhoneAuthCredentials.normalizePhone(phoneRaw);
    if (!PhoneAuthCredentials.isValidIraqiPhone(phoneRaw)) {
      throw FirebaseAuthException(
        code: 'invalid-phone',
        message: 'Enter a valid Iraqi phone number.',
      );
    }

    try {
      return await _requestPasswordResetLinkFromCallable(phone);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: error.message,
        );
      }
      rethrow;
    }
  }

  Future<void> resetPasswordByPhone({
    required String phoneRaw,
    required String newPassword,
  }) async {
    final phone = PhoneAuthCredentials.normalizePhone(phoneRaw);
    if (!PhoneAuthCredentials.isValidIraqiPhone(phoneRaw)) {
      throw FirebaseAuthException(
        code: 'invalid-phone',
        message: 'Enter a valid Iraqi phone number.',
      );
    }
    if (!PhoneAuthCredentials.isValidPassword(newPassword)) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters.',
      );
    }

    try {
      final callable = _functions.httpsCallable('resetPasswordByPhone');
      await callable.call({
        'phone': phone,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (error) {
      throw authExceptionFromFunctions(error);
    }
  }

  Future<String> _requestPasswordResetLinkFromCallable(String phone) async {
    final callable = _functions.httpsCallable('requestPasswordReset');
    final result = await callable.call({'phone': phone});
    final data = Map<String, dynamic>.from(result.data as Map);
    final link = data['resetLink'] as String?;
    if (link == null || link.isEmpty) {
      throw FirebaseAuthException(
        code: 'reset-failed',
        message: 'Could not create password reset link.',
      );
    }
    return link;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Not signed in');
    }
    if (!PhoneAuthCredentials.isValidPassword(newPassword)) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> updateAccountPhone({
    required String currentPassword,
    required String newPhoneRaw,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('Not signed in');
    }

    final newPhone = PhoneAuthCredentials.normalizePhone(newPhoneRaw);

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    final callable = _functions.httpsCallable('updateAccountPhone');
    await callable.call({'newPhone': newPhone});
  }

  Future<void> updateUserProfileFields({
    required String name,
    int? age,
    String? gender,
    String? email,
    String? profilePhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final payload = <String, dynamic>{
      'name': name.trim(),
      if (age != null) 'age': age,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (email != null) 'email': email.trim(),
      if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
        'profilePhotoUrl': profilePhotoUrl,
    };

    await _firestore.collection('users').doc(user.uid).set(
      payload,
      SetOptions(merge: true),
    );
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AppUser?> getCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(user.uid, doc.data()!);
  }

  Stream<AppUser?> watchCurrentProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return watchUser(user.uid);
  }

  Stream<AppUser?> watchUser(String uid) {
    if (uid.isEmpty) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> saveUserProfile({
    required UserRole role,
    required String name,
    required int age,
    String? gender,
    String? phone,
    String? email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final existingPhone = doc.data()?['phone'] as String?;

    await _firestore.collection('users').doc(user.uid).set({
      'phone': phone ?? existingPhone ?? _phoneFromAuthEmail(user.email ?? ''),
      'role': role.value,
      'name': name,
      'age': age,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (email != null && email.isNotEmpty) 'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Recreates the Firestore profile when Firebase Auth still exists but
  /// `users/{uid}` was deleted from the database.
  Future<void> restoreMissingProfile({
    required UserRole role,
    required String name,
    String? phone,
    String? email,
    int age = 18,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Name is required');
    }

    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    if (existing.exists && existing.data() != null) {
      return;
    }

    final resolvedPhone = (phone ?? _phoneFromAuthEmail(user.email ?? '')).trim();
    final resolvedEmail = email ??
        (user.email != null &&
                user.email!.contains('@') &&
                !user.email!.endsWith('@hello-tiktok.app')
            ? user.email
            : null);

    await docRef.set({
      'phone': resolvedPhone,
      'role': role.value,
      'name': trimmedName,
      'age': age,
      if (resolvedEmail != null && resolvedEmail.trim().isNotEmpty)
        'email': resolvedEmail.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (role == UserRole.customer) ...await _customerPromoFields(),
    });
  }

  String _phoneFromAuthEmail(String authEmail) {
    if (!authEmail.endsWith('@hello-tiktok.app')) return '';
    final digits = authEmail.split('@').first.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('964')) return '+$digits';
    return '+964$digits';
  }
}

class DriverService {
  DriverService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  StreamSubscription<Position>? _locationSubscription;
  DateTime? _lastLocationWriteAt;
  Position? _lastWrittenPosition;
  LatLng? _workAreaCenter;
  double _workAreaMaxGpsDriftKm = 35;

  Future<void> submitRegistration({
    required String uid,
    required String phone,
    required String name,
    required String vehicleType,
    String vehiclePlate = '',
    String licenseNumber = '',
    required String idPhotoUrl,
    required String profilePhotoUrl,
  }) async {
    await _firestore.collection('drivers').doc(uid).set({
      'phone': phone,
      'name': name,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
      'licenseNumber': licenseNumber,
      'idPhotoUrl': idPhotoUrl,
      'profilePhotoUrl': profilePhotoUrl,
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'approvalStatus': DriverApprovalStatus.pending.value,
      'isOnline': false,
      'isBlocked': false,
      'hasActiveRide': false,
      'cancelledRidesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    String? vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
    String? profilePhotoUrl,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      if (vehicleType != null) 'vehicleType': vehicleType.trim(),
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate.trim(),
      if (licenseNumber != null) 'licenseNumber': licenseNumber.trim(),
      if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
        'profilePhotoUrl': profilePhotoUrl,
    };

    await _firestore.collection('drivers').doc(uid).set(
      payload,
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(uid).set(
      {'name': name.trim()},
      SetOptions(merge: true),
    );
  }

  Stream<DriverProfile?> watchDriver(String uid) {
    return _firestore.collection('drivers').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return DriverProfile.fromMap(uid, doc.data()!);
    });
  }

  Stream<List<DriverProfile>> watchPendingDrivers() {
    return _firestore
        .collection('drivers')
        .where('approvalStatus', isEqualTo: DriverApprovalStatus.pending.value)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverProfile.fromMap(doc.id, doc.data()))
          .where((driver) => !driver.isRemoved)
          .toList();
    });
  }

  Future<void> setApprovalStatus({
    required String driverId,
    required DriverApprovalStatus status,
  }) async {
    final payload = <String, dynamic>{
      'approvalStatus': status.value,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (status == DriverApprovalStatus.approved) 'isBlocked': false,
    };

    if (status == DriverApprovalStatus.approved) {
      final existing = await _firestore.collection('drivers').doc(driverId).get();
      final districtId = existing.data()?['assignedDistrictId'] as String? ?? '';
      final subDistrictId =
          existing.data()?['assignedSubDistrictId'] as String? ?? '';
      if (districtId.isEmpty || subDistrictId.isEmpty) {
        // Manager must assign work city/sub-district before the driver can go online.
      } else {
        final sub = BabilRegions.subDistrictById(districtId, subDistrictId);
        payload.addAll({
          if (existing.data()?['latitude'] == null)
            'latitude': sub.center.latitude,
          if (existing.data()?['longitude'] == null)
            'longitude': sub.center.longitude,
          if ((existing.data()?['geohash'] as String? ?? '').isEmpty)
            'geohash': Geohash.encode(sub.center.latitude, sub.center.longitude),
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await _firestore.collection('drivers').doc(driverId).update(payload);
  }

  Future<void> setDriverBlocked({
    required String driverId,
    required bool blocked,
  }) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'isBlocked': blocked,
      'blockedAt': blocked ? FieldValue.serverTimestamp() : null,
      if (blocked) 'isOnline': false,
    });
  }

  Future<void> setOnlineStatus({
    required String driverId,
    required bool isOnline,
  }) async {
    if (isOnline) {
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      final data = driverDoc.data();
      if (data == null) return;
      if (data['isBlocked'] as bool? ?? false) {
        throw StateError('blocked');
      }
      if (data['isRemoved'] as bool? ?? false) {
        throw StateError('removed');
      }
      if (data['approvalStatus'] != DriverApprovalStatus.approved.value) {
        throw StateError('not_approved');
      }

      await _repairStaleActiveRideFlag(driverId);

      final districtId = data['assignedDistrictId'] as String? ?? '';
      final subDistrictId = data['assignedSubDistrictId'] as String? ?? '';
      if (districtId.isEmpty || subDistrictId.isEmpty) {
        throw StateError('work_area_required');
      }

      final sub = BabilRegions.subDistrictById(districtId, subDistrictId);
      _workAreaCenter = sub.center;
      _workAreaMaxGpsDriftKm = sub.searchRadiusKm + 12;

      await _firestore.collection('drivers').doc(driverId).update({
        'isOnline': true,
        'hasActiveRide': false,
        if (data['latitude'] == null) 'latitude': sub.center.latitude,
        if (data['longitude'] == null) 'longitude': sub.center.longitude,
        if ((data['geohash'] as String? ?? '').isEmpty)
          'geohash': Geohash.encode(sub.center.latitude, sub.center.longitude),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      await _startLocationUpdates(driverId);
      return;
    }

    _workAreaCenter = null;
    await _firestore.collection('drivers').doc(driverId).update({
      'isOnline': false,
    });
    await _stopLocationUpdates();
  }

  Future<void> refreshOnlineMatchingProfile(String driverId) async {
    final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
    final data = driverDoc.data();
    if (data == null || data['isOnline'] != true) return;
    if (data['approvalStatus'] != DriverApprovalStatus.approved.value) return;
    if (data['isBlocked'] as bool? ?? false) return;
    if (data['isRemoved'] as bool? ?? false) return;

    await _repairStaleActiveRideFlag(driverId);

    final districtId = data['assignedDistrictId'] as String? ?? '';
    final subDistrictId = data['assignedSubDistrictId'] as String? ?? '';
    if (districtId.isEmpty || subDistrictId.isEmpty) return;

    final sub = BabilRegions.subDistrictById(districtId, subDistrictId);
    _workAreaCenter = sub.center;
    _workAreaMaxGpsDriftKm = sub.searchRadiusKm + 12;

    final needsLocationSeed =
        data['latitude'] == null ||
        data['longitude'] == null ||
        (data['geohash'] as String? ?? '').isEmpty;
    if (!needsLocationSeed) return;

    await _firestore.collection('drivers').doc(driverId).update({
      if (data['latitude'] == null) 'latitude': sub.center.latitude,
      if (data['longitude'] == null) 'longitude': sub.center.longitude,
      if ((data['geohash'] as String? ?? '').isEmpty)
        'geohash': Geohash.encode(sub.center.latitude, sub.center.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _repairStaleActiveRideFlag(String driverId) async {
    final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
    if (driverDoc.data()?['hasActiveRide'] != true) return;

    final activeRide = await _firestore
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          RideStatus.matched.value,
          RideStatus.accepted.value,
          RideStatus.inProgress.value,
          RideStatus.awaitingCashPayment.value,
        ])
        .limit(1)
        .get();

    if (activeRide.docs.isEmpty) {
      await _firestore.collection('drivers').doc(driverId).update({
        'hasActiveRide': false,
      });
    }
  }

  Future<void> _startLocationUpdates(String driverId) async {
    await _stopLocationUpdates();
    _lastLocationWriteAt = null;
    _lastWrittenPosition = null;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await _writeDriverLocation(driverId, position, force: true);
    } catch (_) {}

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        distanceFilter: 15,
        accuracy: LocationAccuracy.best,
      ),
    ).listen((position) async {
      await _writeDriverLocation(driverId, position);
    });
  }

  Future<void> _writeDriverLocation(
    String driverId,
    Position position, {
    bool force = false,
  }) async {
    if (_workAreaCenter != null) {
      const distance = Distance();
      final driftKm = distance.as(
        LengthUnit.Kilometer,
        _workAreaCenter!,
        LatLng(position.latitude, position.longitude),
      );
      if (driftKm > _workAreaMaxGpsDriftKm) {
        return;
      }
    }

    if (!force &&
        _lastLocationWriteAt != null &&
        _lastWrittenPosition != null) {
      final elapsed = DateTime.now().difference(_lastLocationWriteAt!);
      final movedMeters = Geolocator.distanceBetween(
        _lastWrittenPosition!.latitude,
        _lastWrittenPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (elapsed.inSeconds < 10 && movedMeters < 25) {
        return;
      }
    }

    _lastLocationWriteAt = DateTime.now();
    _lastWrittenPosition = position;

    await _firestore.collection('drivers').doc(driverId).update({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'geohash': Geohash.encode(position.latitude, position.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Stream<DriverProfile?> watchDriverLocation(String driverId) {
    return watchDriver(driverId);
  }

  Future<List<DriverProfile>> getAvailableDriversNear(
    LatLng pickup, {
    Set<String> excludeDriverIds = const {},
  }) async {
    final prefixes = Geohash.searchPrefixes(pickup.latitude, pickup.longitude);
    final seenDriverIds = <String>{};
    final candidates = <DriverProfile>[];

    Future<void> collectFromQuery(Query<Map<String, dynamic>> query) async {
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        if (seenDriverIds.contains(doc.id)) continue;
        seenDriverIds.add(doc.id);
        candidates.add(DriverProfile.fromMap(doc.id, doc.data()));
      }
    }

    for (final prefix in prefixes) {
      await collectFromQuery(
        _firestore
            .collection('drivers')
            .where('approvalStatus', isEqualTo: DriverApprovalStatus.approved.value)
            .where('isOnline', isEqualTo: true)
            .where('geohash', isGreaterThanOrEqualTo: prefix)
            .where('geohash', isLessThan: Geohash.upperBound(prefix))
            .limit(DriverSearchConfig.perPrefixQueryLimit),
      );
      if (candidates.length >= DriverSearchConfig.maxCandidates) break;
    }

    if (candidates.isEmpty) {
      await collectFromQuery(
        _firestore
            .collection('drivers')
            .where('approvalStatus', isEqualTo: DriverApprovalStatus.approved.value)
            .where('isOnline', isEqualTo: true)
            .limit(DriverSearchConfig.maxCandidates),
      );
    }

    final distance = const Distance();
    final drivers = candidates
        .where(
          (driver) =>
              driver.isAvailableForRides &&
              !excludeDriverIds.contains(driver.uid),
        )
        .where((driver) {
          final km = distance.as(
            LengthUnit.Kilometer,
            pickup,
            LatLng(driver.latitude!, driver.longitude!),
          );
          return km <= DriverSearchConfig.maxPickupRadiusKm;
        })
        .toList();

    drivers.sort((a, b) {
      final aDistance = distance.as(
        LengthUnit.Kilometer,
        pickup,
        LatLng(a.latitude!, a.longitude!),
      );
      final bDistance = distance.as(
        LengthUnit.Kilometer,
        pickup,
        LatLng(b.latitude!, b.longitude!),
      );
      final distanceCompare = aDistance.compareTo(bDistance);
      if (distanceCompare != 0) return distanceCompare;
      return a.completedRidesCount.compareTo(b.completedRidesCount);
    });

    return drivers;
  }

  Future<List<DriverProfile>> getAvailableDriversForDistrict(
    String districtId, {
    String? subDistrictId,
    Set<String> excludeDriverIds = const {},
  }) async {
    if (districtId.trim().isEmpty) return const [];
    final trimmedSub = subDistrictId?.trim() ?? '';

    try {
      var query = _firestore
          .collection('drivers')
          .where('approvalStatus', isEqualTo: DriverApprovalStatus.approved.value)
          .where('isOnline', isEqualTo: true)
          .where('assignedDistrictId', isEqualTo: districtId.trim());

      if (trimmedSub.isNotEmpty) {
        query = query.where('assignedSubDistrictId', isEqualTo: trimmedSub);
      }

      final snapshot =
          await query.limit(DriverSearchConfig.maxCandidates).get();

      return _filterAvailableDrivers(
        snapshot.docs,
        excludeDriverIds: excludeDriverIds,
        districtId: districtId.trim(),
        subDistrictId: trimmedSub.isEmpty ? null : trimmedSub,
      );
    } catch (_) {
      return _queryOnlineDriversFallback(
        districtId: districtId.trim(),
        subDistrictId: trimmedSub.isEmpty ? null : trimmedSub,
        excludeDriverIds: excludeDriverIds,
      );
    }
  }

  LatLng _driverSortPoint(DriverProfile driver) {
    if (driver.latitude != null && driver.longitude != null) {
      return LatLng(driver.latitude!, driver.longitude!);
    }
    if (driver.hasAssignedWorkArea) {
      final sub = BabilRegions.subDistrictById(
        driver.assignedDistrictId,
        driver.assignedSubDistrictId,
      );
      return sub.center;
    }
    return BabilRegions.customerDistrict.subDistricts.first.center;
  }

  Future<List<DriverProfile>> findDriversForRide({
    required String districtId,
    required String subDistrictId,
    required LatLng pickup,
    Set<String> excludeDriverIds = const {},
  }) async {
    final trimmedDistrict = districtId.trim();
    final trimmedSub = subDistrictId.trim();
    if (trimmedDistrict.isEmpty || trimmedSub.isEmpty) return const [];

    var drivers = await getAvailableDriversForDistrict(
      trimmedDistrict,
      subDistrictId: trimmedSub,
      excludeDriverIds: excludeDriverIds,
    );

    if (drivers.isEmpty) {
      drivers = await _queryOnlineDriversFallback(
        districtId: trimmedDistrict,
        subDistrictId: trimmedSub,
        excludeDriverIds: excludeDriverIds,
      );
    }

    final distance = const Distance();
    drivers.sort((a, b) {
      final aDistance = distance.as(
        LengthUnit.Kilometer,
        pickup,
        _driverSortPoint(a),
      );
      final bDistance = distance.as(
        LengthUnit.Kilometer,
        pickup,
        _driverSortPoint(b),
      );
      final distanceCompare = aDistance.compareTo(bDistance);
      if (distanceCompare != 0) return distanceCompare;
      return a.completedRidesCount.compareTo(b.completedRidesCount);
    });

    return drivers;
  }

  List<DriverProfile> _filterAvailableDrivers(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required Set<String> excludeDriverIds,
    String? districtId,
    String? subDistrictId,
  }) {
    final drivers = docs
        .map((doc) => DriverProfile.fromMap(doc.id, doc.data()))
        .where(
          (driver) =>
              driver.isAvailableForRides &&
              !excludeDriverIds.contains(driver.uid),
        )
        .where((driver) {
          if (districtId != null &&
              districtId.isNotEmpty &&
              driver.assignedDistrictId != districtId) {
            return false;
          }
          if (subDistrictId != null &&
              subDistrictId.isNotEmpty &&
              driver.assignedSubDistrictId != subDistrictId) {
            return false;
          }
          return true;
        })
        .toList();

    drivers.sort(
      (a, b) => a.completedRidesCount.compareTo(b.completedRidesCount),
    );
    return drivers;
  }

  Future<List<DriverProfile>> _queryOnlineDriversFallback({
    required String districtId,
    String? subDistrictId,
    Set<String> excludeDriverIds = const {},
  }) async {
    final snapshot = await _firestore
        .collection('drivers')
        .where('approvalStatus', isEqualTo: DriverApprovalStatus.approved.value)
        .where('isOnline', isEqualTo: true)
        .limit(DriverSearchConfig.maxCandidates)
        .get();

    return _filterAvailableDrivers(
      snapshot.docs,
      excludeDriverIds: excludeDriverIds,
      districtId: districtId,
      subDistrictId: subDistrictId,
    );
  }

  Future<void> dispose() => _stopLocationUpdates();
}

class RideService {
  RideService({
    FirebaseFirestore? firestore,
    required DriverService driverService,
    CommissionService? commissionService,
    MonthlyPrizeService? monthlyPrizeService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _driverService = driverService,
        _commissionService = commissionService ?? CommissionService(),
        _monthlyPrizeService = monthlyPrizeService ?? MonthlyPrizeService();

  final FirebaseFirestore _firestore;
  final DriverService _driverService;
  final CommissionService _commissionService;
  final MonthlyPrizeService _monthlyPrizeService;
  final _uuid = const Uuid();

  static const _activeCustomerRideStatuses = [
    RideStatus.searching,
    RideStatus.matched,
    RideStatus.accepted,
    RideStatus.inProgress,
    RideStatus.awaitingCashPayment,
  ];

  Future<void> _ensureCustomerHasNoActiveRide(String customerId) async {
    final snapshot = await _firestore
        .collection('rides')
        .where('customerId', isEqualTo: customerId)
        .where(
          'status',
          whereIn: _activeCustomerRideStatuses
              .map((status) => status.value)
              .toList(),
        )
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      throw StateError('active_ride_exists');
    }
  }

  Set<String> _rejectedDriverIdsFromData(Map<String, dynamic> data) {
    return (data['rejectedDriverIds'] as List<dynamic>?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        const {};
  }

  Future<void> _setDriverActiveRide(String driverId, bool hasActiveRide) async {
    if (driverId.isEmpty) return;
    await _firestore.collection('drivers').doc(driverId).update({
      'hasActiveRide': hasActiveRide,
    });
  }

  Future<Ride> bookRide({
    required String customerId,
    required String pickupLabel,
    required String destinationLabel,
    required LatLng pickup,
    required LatLng destination,
    required String districtId,
    required String subDistrictId,
    required int fareAmountIqd,
    required double distanceKm,
    int originalFareIqd = 0,
    int promoDiscountIqd = 0,
    String promoCode = '',
  }) async {
    if (!RideLocationRules.areDistinct(pickup, destination)) {
      throw StateError('pickup_destination_same');
    }

    await _ensureCustomerHasNoActiveRide(customerId);

    final rideId = _uuid.v4();
    final rideRef = _firestore.collection('rides').doc(rideId);

    final ride = Ride(
      id: rideId,
      customerId: customerId,
      pickupLabel: pickupLabel,
      destinationLabel: destinationLabel,
      pickupLat: pickup.latitude,
      pickupLng: pickup.longitude,
      destinationLat: destination.latitude,
      destinationLng: destination.longitude,
      status: RideStatus.searching,
      createdAt: DateTime.now(),
      fareAmountIqd: fareAmountIqd,
      paymentMethod: PaymentMethod.cash,
    );

    final pickupRegion = BabilRegions.resolveFromPoint(pickup);
    final resolvedDistrictId = districtId.trim().isNotEmpty
        ? districtId.trim()
        : pickupRegion.districtId;
    final resolvedSubDistrictId = subDistrictId.trim().isNotEmpty
        ? subDistrictId.trim()
        : pickupRegion.subDistrictId;

    await rideRef.set({
      ...ride.toMap(),
      'districtId': resolvedDistrictId,
      'subDistrictId': resolvedSubDistrictId,
      'distanceKm': distanceKm,
      if (originalFareIqd > 0) 'originalFareIqd': originalFareIqd,
      if (promoDiscountIqd > 0) 'promoDiscountIqd': promoDiscountIqd,
      if (promoCode.isNotEmpty) 'promoCode': promoCode,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _assignNearestDriverImpl(rideId);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Driver assignment failed for $rideId: $error\n$stackTrace');
      }
    }

    final latest = await rideRef.get();
    if (latest.exists && latest.data() != null) {
      return Ride.fromMap(rideId, latest.data()!);
    }
    return Ride(
      id: rideId,
      customerId: customerId,
      pickupLabel: pickupLabel,
      destinationLabel: destinationLabel,
      pickupLat: pickup.latitude,
      pickupLng: pickup.longitude,
      destinationLat: destination.latitude,
      destinationLng: destination.longitude,
      status: RideStatus.searching,
      createdAt: ride.createdAt,
      fareAmountIqd: fareAmountIqd,
      paymentMethod: PaymentMethod.cash,
      districtId: resolvedDistrictId,
      subDistrictId: resolvedSubDistrictId,
    );
  }

  Future<Ride> assignNearestDriver(
    String rideId, {
    Set<String> excludeDriverIds = const {},
  }) {
    return _assignNearestDriverImpl(
      rideId,
      excludeDriverIds: excludeDriverIds,
    ).timeout(const Duration(seconds: 30));
  }

  Future<Ride> _assignNearestDriverImpl(
    String rideId, {
    Set<String> excludeDriverIds = const {},
  }) async {
    final rideRef = _firestore.collection('rides').doc(rideId);
    final snapshot = await rideRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      throw StateError('ride_not_found');
    }

    final ride = Ride.fromMap(rideId, snapshot.data()!);
    if (ride.status == RideStatus.matched ||
        ride.status == RideStatus.accepted ||
        ride.status == RideStatus.inProgress ||
        ride.status == RideStatus.awaitingCashPayment) {
      return ride;
    }
    if (ride.status == RideStatus.cancelled ||
        ride.status == RideStatus.completed) {
      throw StateError('ride_cancelled');
    }

    var districtId = ride.districtId.trim();
    var subDistrictId = ride.subDistrictId.trim();
    if (districtId.isEmpty || subDistrictId.isEmpty) {
      final resolved = BabilRegions.resolveFromPoint(
        LatLng(ride.pickupLat, ride.pickupLng),
      );
      districtId = districtId.isEmpty ? resolved.districtId : districtId;
      subDistrictId =
          subDistrictId.isEmpty ? resolved.subDistrictId : subDistrictId;
    }

    final rejectedDriverIds = _rejectedDriverIdsFromData(snapshot.data()!);
    final districtDrivers = await _driverService.findDriversForRide(
      districtId: districtId,
      subDistrictId: subDistrictId,
      pickup: LatLng(ride.pickupLat, ride.pickupLng),
      excludeDriverIds: {...excludeDriverIds, ...rejectedDriverIds},
    );

    if (districtDrivers.isEmpty) {
      throw StateError('no_drivers');
    }

    DriverProfile? autoAcceptDriver;
    for (final driver in districtDrivers) {
      if (driver.isFakeDriver && driver.autoAcceptRides) {
        autoAcceptDriver = driver;
        break;
      }
    }

    if (autoAcceptDriver != null) {
      final matchedDriver = autoAcceptDriver;
      final acceptedRide = await _firestore.runTransaction((transaction) async {
        final latest = await transaction.get(rideRef);
        final latestData = latest.data();
        if (latestData == null) {
          throw StateError('ride_not_found');
        }

        final latestStatus =
            RideStatusX.fromString(latestData['status'] as String?);
        if (latestStatus == RideStatus.cancelled ||
            latestStatus == RideStatus.completed) {
          throw StateError('ride_cancelled');
        }
        if (latestStatus != RideStatus.searching) {
          throw StateError('ride_unavailable');
        }

        transaction.update(rideRef, {
          'driverId': matchedDriver.uid,
          'offeredDriverIds': [matchedDriver.uid],
          'status': RideStatus.accepted.value,
          'matchedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          'notifyCustomer': true,
        });

        return Ride.fromMap(rideId, latestData).copyWith(
          driverId: matchedDriver.uid,
          status: RideStatus.accepted,
          offeredDriverIds: [matchedDriver.uid],
        );
      });
      await _setDriverActiveRide(matchedDriver.uid, true);
      return acceptedRide;
    }

    final offeredDriverIds = districtDrivers.map((driver) => driver.uid).toList();

    return _firestore.runTransaction((transaction) async {
      final latest = await transaction.get(rideRef);
      final latestData = latest.data();
      if (latestData == null) {
        throw StateError('ride_not_found');
      }

      final latestStatus =
          RideStatusX.fromString(latestData['status'] as String?);
      if (latestStatus == RideStatus.cancelled ||
          latestStatus == RideStatus.completed) {
        throw StateError('ride_cancelled');
      }
      if (latestStatus != RideStatus.searching) {
        throw StateError('ride_unavailable');
      }

      transaction.update(rideRef, {
        'offeredDriverIds': offeredDriverIds,
        'status': RideStatus.matched.value,
        'matchedAt': FieldValue.serverTimestamp(),
        'notifyDrivers': true,
      });

      return Ride.fromMap(rideId, latestData).copyWith(
        status: RideStatus.matched,
        offeredDriverIds: offeredDriverIds,
      );
    });
  }

  Future<Ride> requestRide({
    required String customerId,
    required String pickupLabel,
    required String destinationLabel,
    required LatLng pickup,
    required LatLng destination,
  }) async {
    final pricing = PricingService();
    final quote = await pricing.quoteRide(
      pickup: pickup,
      destination: destination,
      districtId: BabilRegions.customerDistrictId,
    );
    if (!quote.canBook || quote.fareIqd == null) {
      throw StateError('out_of_service');
    }

    final customerDistrict = BabilRegions.customerDistrict;
    final ride = await bookRide(
      customerId: customerId,
      pickupLabel: pickupLabel,
      destinationLabel: destinationLabel,
      pickup: pickup,
      destination: destination,
      districtId: customerDistrict.id,
      subDistrictId: customerDistrict.subDistricts.first.id,
      fareAmountIqd: quote.fareIqd!,
      distanceKm: quote.distanceKm,
    );
    try {
      return await assignNearestDriver(ride.id);
    } catch (_) {
      rethrow;
    }
  }

  Stream<Ride?> watchRide(String rideId) {
    return _firestore.collection('rides').doc(rideId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Ride.fromMap(doc.id, doc.data()!);
    });
  }

  Ride? _latestActiveRideFromDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    Ride? latest;
    DateTime? latestCreatedAt;
    for (final doc in docs) {
      final ride = Ride.fromMap(doc.id, doc.data());
      final createdAt = ride.createdAt;
      if (latest == null ||
          (createdAt != null &&
              (latestCreatedAt == null || createdAt.isAfter(latestCreatedAt)))) {
        latest = ride;
        latestCreatedAt = createdAt;
      }
    }
    return latest;
  }

  Future<Ride?> fetchActiveRideForCustomer(String customerId) async {
    final snapshot = await _firestore
        .collection('rides')
        .where('customerId', isEqualTo: customerId)
        .where(
          'status',
          whereIn: _activeCustomerRideStatuses
              .map((status) => status.value)
              .toList(),
        )
        .get()
        .timeout(const Duration(seconds: 8));
    return _latestActiveRideFromDocs(snapshot.docs);
  }

  Stream<Ride?> watchActiveRideForCustomer(String customerId) {
    return _firestore
        .collection('rides')
        .where('customerId', isEqualTo: customerId)
        .where('status', whereIn: [
          RideStatus.searching.value,
          RideStatus.matched.value,
          RideStatus.accepted.value,
          RideStatus.inProgress.value,
          RideStatus.awaitingCashPayment.value,
        ])
        .snapshots()
        .map((snapshot) => _latestActiveRideFromDocs(snapshot.docs));
  }

  Ride? _driverVisibleRide(Ride? ride, {required String driverId}) {
    if (ride == null) return null;
    if (ride.status == RideStatus.cancelled ||
        ride.status == RideStatus.completed) {
      return null;
    }
    final assignedDriverId = ride.driverId;
    if (assignedDriverId != null &&
        assignedDriverId.isNotEmpty &&
        assignedDriverId != driverId) {
      return null;
    }
    return ride;
  }

  Stream<Ride?> watchAssignedRideForDriver(String driverId) {
    late final StreamController<Ride?> controller;
    Ride? assignedRide;
    Ride? offeredRide;
    Ride? searchingRide;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? assignedSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? offeredSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subDistrictSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? driverSubscription;

    controller = StreamController<Ride?>.broadcast(
      onListen: () {
        Ride? current;

        void publish() {
          final assigned = _driverVisibleRide(assignedRide, driverId: driverId);
          final next = assigned ??
              _driverVisibleRide(offeredRide, driverId: driverId) ??
              _driverVisibleRide(searchingRide, driverId: driverId);
          if (next?.id == current?.id &&
              next?.status == current?.status &&
              next?.driverId == current?.driverId) {
            return;
          }
          current = next;
          controller.add(next);
        }

        void bindSubDistrictListeners({
          required String districtId,
          required String subDistrictId,
        }) {
          subDistrictSubscription?.cancel();
          subDistrictSubscription = _firestore
              .collection('rides')
              .where('districtId', isEqualTo: districtId)
              .where('subDistrictId', isEqualTo: subDistrictId)
              .where(
                'status',
                whereIn: [RideStatus.searching.value, RideStatus.matched.value],
              )
              .limit(10)
              .snapshots()
              .listen((snapshot) {
            searchingRide = null;
            Ride? matchedInSubdistrict;
            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data['driverId'] != null) continue;
              final ride = Ride.fromMap(doc.id, data);
              if (ride.status == RideStatus.searching) {
                searchingRide = ride;
                break;
              }
              if (ride.status == RideStatus.matched &&
                  (ride.offeredDriverIds.isEmpty ||
                      ride.offeredDriverIds.contains(driverId))) {
                matchedInSubdistrict = ride;
              }
            }
            if (searchingRide == null && matchedInSubdistrict != null) {
              offeredRide = matchedInSubdistrict;
            }
            publish();
          });
        }

        assignedSubscription = _firestore
            .collection('rides')
            .where('driverId', isEqualTo: driverId)
            .where('status', whereIn: [
              RideStatus.accepted.value,
              RideStatus.inProgress.value,
              RideStatus.awaitingCashPayment.value,
            ])
            .limit(1)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.docs.isEmpty) {
            assignedRide = null;
          } else {
            final doc = snapshot.docs.first;
            assignedRide = Ride.fromMap(doc.id, doc.data());
          }
          publish();
        });

        offeredSubscription = _firestore
            .collection('rides')
            .where('offeredDriverIds', arrayContains: driverId)
            .where('status', isEqualTo: RideStatus.matched.value)
            .limit(5)
            .snapshots()
            .listen((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['driverId'] != null) continue;
            offeredRide = Ride.fromMap(doc.id, data);
            publish();
            return;
          }
        });

        driverSubscription = _firestore
            .collection('drivers')
            .doc(driverId)
            .snapshots()
            .listen((driverSnap) {
          if (controller.isClosed || !driverSnap.exists) return;
          final driverData = driverSnap.data();
          if (driverData == null) return;
          final districtId = driverData['assignedDistrictId'] as String? ?? '';
          final subDistrictId =
              driverData['assignedSubDistrictId'] as String? ?? '';
          if (districtId.isEmpty || subDistrictId.isEmpty) {
            subDistrictSubscription?.cancel();
            subDistrictSubscription = null;
            searchingRide = null;
            publish();
            return;
          }
          bindSubDistrictListeners(
            districtId: districtId,
            subDistrictId: subDistrictId,
          );
        });

        controller.onCancel = () {
          assignedSubscription?.cancel();
          offeredSubscription?.cancel();
          subDistrictSubscription?.cancel();
          driverSubscription?.cancel();
        };
      },
    );

    return controller.stream;
  }

  Stream<List<Ride>> watchRideHistoryForCustomer(
    String customerId, {
    RideStatus? statusFilter,
  }) {
    var query = _firestore
        .collection('rides')
        .where('customerId', isEqualTo: customerId);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snapshot) => statusFilter != null
              ? snapshot.docs
                  .map((doc) => Ride.fromMap(doc.id, doc.data()))
                  .toList()
              : _historyFromSnapshot(snapshot),
        );
  }

  Stream<List<Ride>> watchRideHistoryForDriver(
    String driverId, {
    RideStatus? statusFilter,
  }) {
    var query =
        _firestore.collection('rides').where('driverId', isEqualTo: driverId);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }
    return query
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map(
          (snapshot) => statusFilter != null
              ? snapshot.docs
                  .map((doc) => Ride.fromMap(doc.id, doc.data()))
                  .toList()
              : _historyFromSnapshot(snapshot),
        );
  }

  List<Ride> _historyFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rides = snapshot.docs
        .map((doc) => Ride.fromMap(doc.id, doc.data()))
        .where(
          (ride) =>
              ride.status == RideStatus.completed ||
              ride.status == RideStatus.cancelled,
        )
        .toList();
    rides.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return rides;
  }

  Future<void> acceptRide({
    required String rideId,
    required String driverId,
  }) async {
    final ref = _firestore.collection('rides').doc(rideId);
    final driverRef = _firestore.collection('drivers').doc(driverId);

    await _firestore.runTransaction((transaction) async {
      final driverSnap = await transaction.get(driverRef);
      if (driverSnap.data()?['hasActiveRide'] == true) {
        throw StateError('driver_busy');
      }

      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('ride_not_found');
      }

      final status = RideStatusX.fromString(data['status'] as String?);
      if (status != RideStatus.matched && status != RideStatus.searching) {
        throw StateError('ride_unavailable');
      }

      final assignedDriverId = data['driverId'] as String?;
      if (assignedDriverId != null &&
          assignedDriverId.isNotEmpty &&
          assignedDriverId != driverId) {
        throw StateError('ride_taken');
      }

      if (status == RideStatus.searching) {
        final rideDistrictId = data['districtId'] as String? ?? '';
        final rideSubDistrictId = data['subDistrictId'] as String? ?? '';
        final driverDistrictId =
            driverSnap.data()?['assignedDistrictId'] as String? ?? '';
        final driverSubDistrictId =
            driverSnap.data()?['assignedSubDistrictId'] as String? ?? '';
        if (rideDistrictId.isEmpty ||
            rideSubDistrictId.isEmpty ||
            driverDistrictId != rideDistrictId ||
            driverSubDistrictId != rideSubDistrictId) {
          throw StateError('ride_unavailable');
        }
      } else {
        final offeredDriverIds = (data['offeredDriverIds'] as List<dynamic>?)
                ?.map((value) => value.toString())
                .where((value) => value.isNotEmpty)
                .toList() ??
            const <String>[];
        if (assignedDriverId == null &&
            offeredDriverIds.isNotEmpty &&
            !offeredDriverIds.contains(driverId)) {
          throw StateError('ride_unavailable');
        }
      }

      transaction.update(ref, {
        'driverId': driverId,
        'status': RideStatus.accepted.value,
        'acceptedAt': FieldValue.serverTimestamp(),
        'offeredDriverIds': <String>[],
        'notifyDrivers': false,
        'notifyCustomer': true,
      });
      transaction.update(driverRef, {'hasActiveRide': true});
    });

    NotificationService.clearDriverRideOffer(rideId);
  }

  Future<void> rejectRide({
    required String rideId,
    required String driverId,
  }) async {
    final ref = _firestore.collection('rides').doc(rideId);
    var shouldReassign = false;
    final rejectedIds = <String>{driverId};

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('ride_not_found');
      }

      final status = RideStatusX.fromString(data['status'] as String?);
      if (status != RideStatus.matched) {
        throw StateError('ride_unavailable');
      }

      if (data['driverId'] != null) {
        throw StateError('ride_taken');
      }

      final offeredDriverIds = (data['offeredDriverIds'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toList() ??
          const <String>[];
      if (!offeredDriverIds.contains(driverId)) {
        throw StateError('ride_unavailable');
      }

      rejectedIds.addAll(_rejectedDriverIdsFromData(data));
      final remainingOffers =
          offeredDriverIds.where((id) => id != driverId).toList();

      if (remainingOffers.isEmpty) {
        shouldReassign = true;
        transaction.update(ref, {
          'offeredDriverIds': <String>[],
          'rejectedDriverIds': rejectedIds.toList(),
          'status': RideStatus.searching.value,
          'notifyDrivers': false,
        });
      } else {
        transaction.update(ref, {
          'offeredDriverIds': remainingOffers,
          'rejectedDriverIds': rejectedIds.toList(),
        });
      }
    });

    NotificationService.clearDriverRideOffer(rideId);

    if (shouldReassign) {
      try {
        await assignNearestDriver(
          rideId,
          excludeDriverIds: rejectedIds,
        );
      } on StateError catch (error) {
        if (error.message != 'no_drivers' &&
            error.message != 'ride_unavailable') {
          rethrow;
        }
      }
    }
  }

  Future<void> startRide(String rideId) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': RideStatus.inProgress.value,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> endRideAwaitingCash(String rideId) async {
    await _firestore.collection('rides').doc(rideId).update({
      'status': RideStatus.awaitingCashPayment.value,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmCashCollected(String rideId) async {
    final ref = _firestore.collection('rides').doc(rideId);
    final config = await _commissionService.getConfig();
    String? prizeDriverId;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) {
        throw StateError('ride_not_found');
      }

      if (data['earningsApplied'] == true) {
        prizeDriverId = data['driverId'] as String?;
        return;
      }

      final status = RideStatusX.fromString(data['status'] as String?);
      if (status == RideStatus.cancelled) return;
      if (status != RideStatus.awaitingCashPayment &&
          status != RideStatus.completed) {
        throw StateError('ride_not_ready');
      }

      final fare = (data['fareAmountIqd'] as num?)?.toInt() ?? 0;
      final driverId = data['driverId'] as String?;
      final split = _commissionService.splitFare(fare, config.platformPercent);

      transaction.update(ref, {
        'cashCollectedByDriver': true,
        'status': RideStatus.completed.value,
        'completedAt': FieldValue.serverTimestamp(),
        'commissionPercent': split.commissionPercent,
        'platformCommissionIqd': split.platformCommissionIqd,
        'driverEarningsIqd': split.driverEarningsIqd,
        'earningsApplied': true,
      });

      if (driverId != null && driverId.isNotEmpty) {
        prizeDriverId = driverId;
        transaction.update(_firestore.collection('drivers').doc(driverId), {
          'totalFareCollectedIqd': FieldValue.increment(fare),
          'totalPlatformCommissionIqd':
              FieldValue.increment(split.platformCommissionIqd),
          'outstandingPlatformCommissionIqd':
              FieldValue.increment(split.platformCommissionIqd),
          'totalDriverEarningsIqd':
              FieldValue.increment(split.driverEarningsIqd),
          'completedRidesCount': FieldValue.increment(1),
          'hasActiveRide': false,
        });
      }

      final customerId = data['customerId'] as String?;
      final promoCode = data['promoCode'] as String? ?? '';
      if (customerId != null &&
          customerId.isNotEmpty &&
          promoCode.isNotEmpty &&
          (data['promoDiscountIqd'] as num?)?.toInt() != null &&
          (data['promoDiscountIqd'] as num).toInt() > 0) {
        transaction.update(_firestore.collection('users').doc(customerId), {
          'promoRidesUsed': FieldValue.increment(1),
        });
      }
    });

    if (prizeDriverId != null && prizeDriverId!.isNotEmpty) {
      unawaited(_monthlyPrizeService.incrementDriverMonthlyRide(prizeDriverId!));
    }
  }

  /// Applies commission split and updates driver totals for a paid ride.
  /// Safe to retry when cash was collected but earnings were not applied yet.
  Future<void> finishRideAndApplyEarnings(String rideId) async {
    await _completeRide(_firestore.collection('rides').doc(rideId));
  }

  /// Backfills rides where cash was collected but earnings were never applied.
  Future<int> applyPendingEarnings({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('rides')
        .where('cashCollectedByDriver', isEqualTo: true)
        .limit(limit)
        .get();

    var applied = 0;
    for (final doc in snapshot.docs) {
      if (doc.data()['earningsApplied'] == true) continue;
      await _completeRide(doc.reference);
      applied++;
    }
    return applied;
  }

  Future<void> submitDriverRating({
    required String rideId,
    required String customerId,
    required int rating,
    String feedback = '',
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Must be between 1 and 5');
    }

    final ref = _firestore.collection('rides').doc(rideId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) return;

    if (data['customerId'] != customerId) return;
    if (data['status'] != RideStatus.completed.value) return;
    if (data['driverRating'] != null) return;

    final driverId = data['driverId'] as String?;
    final batch = _firestore.batch();

    batch.update(ref, {
      'driverRating': rating,
      'driverFeedback': feedback.trim(),
      'ratedAt': FieldValue.serverTimestamp(),
    });

    if (driverId != null && driverId.isNotEmpty) {
      final driverRef = _firestore.collection('drivers').doc(driverId);
      final driverSnap = await driverRef.get();
      final driverData = driverSnap.data() ?? {};
      final oldCount = (driverData['ratingCount'] as num?)?.toInt() ?? 0;
      final oldRating = (driverData['rating'] as num?)?.toDouble() ?? 5.0;
      final newCount = oldCount + 1;
      final newRating = ((oldRating * oldCount) + rating) / newCount;

      batch.update(driverRef, {
        'rating': newRating,
        'ratingCount': newCount,
      });
    }

    await batch.commit();
  }

  Future<void> _completeRide(DocumentReference<Map<String, dynamic>> ref) async {
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) return;

    final collected = data['cashCollectedByDriver'] as bool? ?? false;
    if (!collected) return;

    if (data['earningsApplied'] == true) {
      if (data['status'] != RideStatus.completed.value) {
        await ref.update({
          'status': RideStatus.completed.value,
          'completedAt': FieldValue.serverTimestamp(),
        });
      }
      final driverId = data['driverId'] as String?;
      if (driverId != null && driverId.isNotEmpty) {
        await _setDriverActiveRide(driverId, false);
      }
      return;
    }

    final status = RideStatusX.fromString(data['status'] as String?);
    if (status == RideStatus.cancelled) return;
    if (status != RideStatus.awaitingCashPayment &&
        status != RideStatus.completed) {
      return;
    }

    final fare = (data['fareAmountIqd'] as num?)?.toInt() ?? 0;
    final driverId = data['driverId'] as String?;
    final config = await _commissionService.getConfig();
    final split = _commissionService.splitFare(fare, config.platformPercent);

    final batch = _firestore.batch();
    batch.update(ref, {
      'status': RideStatus.completed.value,
      'completedAt': FieldValue.serverTimestamp(),
      'commissionPercent': split.commissionPercent,
      'platformCommissionIqd': split.platformCommissionIqd,
      'driverEarningsIqd': split.driverEarningsIqd,
      'earningsApplied': true,
    });

    if (driverId != null && driverId.isNotEmpty) {
      batch.update(_firestore.collection('drivers').doc(driverId), {
        'totalFareCollectedIqd': FieldValue.increment(fare),
        'totalPlatformCommissionIqd':
            FieldValue.increment(split.platformCommissionIqd),
        'outstandingPlatformCommissionIqd':
            FieldValue.increment(split.platformCommissionIqd),
        'totalDriverEarningsIqd': FieldValue.increment(split.driverEarningsIqd),
        'completedRidesCount': FieldValue.increment(1),
        'hasActiveRide': false,
      });
    }

    final customerId = data['customerId'] as String?;
    final promoCode = data['promoCode'] as String? ?? '';
    if (customerId != null &&
        customerId.isNotEmpty &&
        promoCode.isNotEmpty &&
        (data['promoDiscountIqd'] as num?)?.toInt() != null &&
        (data['promoDiscountIqd'] as num).toInt() > 0) {
      batch.update(_firestore.collection('users').doc(customerId), {
        'promoRidesUsed': FieldValue.increment(1),
      });
    }

    await batch.commit();

    if (driverId != null && driverId.isNotEmpty) {
      await _monthlyPrizeService.incrementDriverMonthlyRide(driverId);
    }
  }

  Future<void> cancelRide(
    String rideId, {
    UserRole cancelledBy = UserRole.customer,
  }) async {
    final ref = _firestore.collection('rides').doc(rideId);
    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) return;

    final status = RideStatusX.fromString(data['status'] as String?);
    if (status == RideStatus.completed || status == RideStatus.cancelled) {
      return;
    }
    if (cancelledBy == UserRole.customer &&
        (status == RideStatus.inProgress ||
            status == RideStatus.awaitingCashPayment)) {
      throw StateError('Ride can no longer be cancelled after it has started.');
    }

    await ref.update({
      'status': RideStatus.cancelled.value,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledBy': cancelledBy.value,
      'offeredDriverIds': <String>[],
      'notifyDrivers': false,
      'notifyCustomer': false,
    });

    final assignedDriverId = data['driverId'] as String?;
    if (assignedDriverId != null && assignedDriverId.isNotEmpty) {
      await _setDriverActiveRide(assignedDriverId, false);
    }

    NotificationService.clearDriverRideOffer(rideId);

    try {
      if (cancelledBy == UserRole.customer) {
        final customerId = data['customerId'] as String?;
        if (customerId != null && customerId.isNotEmpty) {
          await _firestore.collection('users').doc(customerId).update({
            'cancelledRidesCount': FieldValue.increment(1),
          });
        }
      } else if (cancelledBy == UserRole.driver) {
        final driverId = data['driverId'] as String?;
        if (driverId != null && driverId.isNotEmpty) {
          await _firestore.collection('drivers').doc(driverId).update({
            'cancelledRidesCount': FieldValue.increment(1),
          });
        }
      }
    } catch (_) {
      // Ride is already cancelled; stats update is best-effort.
    }
  }
}

extension RideCopy on Ride {
  Ride copyWith({
    String? driverId,
    RideStatus? status,
    List<String>? offeredDriverIds,
    int? fareAmountIqd,
    bool? cashCollectedByDriver,
    bool? cashConfirmedByCustomer,
    int? driverRating,
    String? driverFeedback,
    DateTime? ratedAt,
  }) {
    return Ride(
      id: id,
      customerId: customerId,
      driverId: driverId ?? this.driverId,
      offeredDriverIds: offeredDriverIds ?? this.offeredDriverIds,
      pickupLabel: pickupLabel,
      destinationLabel: destinationLabel,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      status: status ?? this.status,
      createdAt: createdAt,
      fareAmountIqd: fareAmountIqd ?? this.fareAmountIqd,
      paymentMethod: paymentMethod,
      cashCollectedByDriver:
          cashCollectedByDriver ?? this.cashCollectedByDriver,
      cashConfirmedByCustomer:
          cashConfirmedByCustomer ?? this.cashConfirmedByCustomer,
      commissionPercent: commissionPercent,
      platformCommissionIqd: platformCommissionIqd,
      driverEarningsIqd: driverEarningsIqd,
      completedAt: completedAt,
      driverRating: driverRating ?? this.driverRating,
      driverFeedback: driverFeedback ?? this.driverFeedback,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }
}
