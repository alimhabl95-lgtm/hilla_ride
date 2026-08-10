import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hilla_ride/core/auth/auth_error_messages.dart';
import 'package:hilla_ride/core/auth/phone_auth_credentials.dart';
import 'package:hilla_ride/core/constants/babil_regions.dart';
import 'package:hilla_ride/core/constants/map_presence_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/wallet_models.dart';
import 'package:hilla_ride/core/utils/ride_location_utils.dart';
import 'package:hilla_ride/core/services/commission_service.dart';
import 'package:hilla_ride/core/services/monthly_prize_service.dart';
import 'package:hilla_ride/core/services/notification_service.dart';
import 'package:hilla_ride/core/services/pricing_service.dart';
import 'package:hilla_ride/core/services/promo_service.dart';
import 'package:hilla_ride/core/services/service_area_catalog.dart';
import 'package:hilla_ride/core/services/session_service.dart';
import 'package:hilla_ride/core/utils/geohash.dart';
import 'package:latlong2/latlong.dart';

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

  /// Permanently deletes the signed-in customer or driver account and all data.
  Future<void> deleteMyAccount() async {
    if (_auth.currentUser == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Not signed in.',
      );
    }
    await _functions.httpsCallable('deleteMyAccount').call();
    await signOut();
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
    final authEmail = PhoneAuthCredentials.toAuthEmail(phone);

    UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        credential = await _retrySignupAfterReleasedPhone(
          phone: phone,
          authEmail: authEmail,
          password: password,
        );
      } else {
        rethrow;
      }
    }

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'internal',
        message: 'Registration failed. Try again.',
      );
    }

    try {
      final trimmedName = fullName.trim();
      if (trimmedName.isNotEmpty && user.displayName != trimmedName) {
        await user.updateDisplayName(trimmedName);
      }

      await _createUserProfileAfterSignup(
        uid: user.uid,
        phone: phone,
        role: role,
        fullName: trimmedName,
        email: email,
        age: age,
      );
      await _sessionService.claimSession(user.uid);
    } catch (error) {
      try {
        await user.delete();
      } catch (_) {
        // Best effort cleanup if profile save fails.
      }
      if (error is FirebaseAuthException) {
        rethrow;
      }
      throw FirebaseAuthException(
        code: 'internal',
        message: 'Could not save account profile. Try again.',
      );
    }

    return credential;
  }

  Future<void> _createUserProfileAfterSignup({
    required String uid,
    required String phone,
    required UserRole role,
    required String fullName,
    String? email,
    int age = 18,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    final existing = await docRef.get();
    if (existing.exists && existing.data() != null) {
      return;
    }

    await docRef.set({
      'phone': phone,
      'role': role.value,
      'name': fullName,
      'age': age,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (role == UserRole.customer) ...await _customerPromoFields(),
    });

    final phoneKey = phone.replaceAll(RegExp(r'\D'), '');
    if (phoneKey.isNotEmpty) {
      try {
        await _firestore.collection('released_phones').doc(phoneKey).delete();
      } catch (_) {
        // Best effort cleanup after successful registration.
      }
    }
  }

  Future<UserCredential> _retrySignupAfterReleasedPhone({
    required String phone,
    required String authEmail,
    required String password,
  }) async {
    final phoneKey = phone.replaceAll(RegExp(r'\D'), '');
    final released =
        await _firestore.collection('released_phones').doc(phoneKey).get();
    if (!released.exists) {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'An account with this phone number already exists.',
      );
    }

    try {
      await _functions.httpsCallable('cleanupReleasedPhoneAuth').call({
        'phone': phone,
      });
    } on FirebaseFunctionsException {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message:
            'This phone number was deleted but is not ready for registration yet. Try again later.',
      );
    }

    try {
      return await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'An account with this phone number already exists.',
        );
      }
      rethrow;
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
  DriverService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
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
    String vehicleColor = '',
    String licenseNumber = '',
    required String idPhotoUrl,
    required String profilePhotoUrl,
  }) async {
    await _functions.httpsCallable('submitDriverRegistration').call({
      'phone': phone,
      'name': name,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
      'vehicleColor': vehicleColor,
      'licenseNumber': licenseNumber,
      'idPhotoUrl': idPhotoUrl,
      'profilePhotoUrl': profilePhotoUrl,
    });
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
        final defaults = BabilRegions.customerDistrict;
        final defaultSub = defaults.subDistricts.first;
        payload.addAll({
          'assignedDistrictId': defaults.id,
          'assignedSubDistrictId': defaultSub.id,
          'latitude': defaultSub.center.latitude,
          'longitude': defaultSub.center.longitude,
          'geohash':
              Geohash.encode(defaultSub.center.latitude, defaultSub.center.longitude),
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        });
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

    await _firestore.collection('drivers').doc(driverId).set(
      payload,
      SetOptions(merge: true),
    );
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

      final walletStatus = data['walletStatus'] as String? ?? 'active';
      final walletBalance = (data['walletBalanceIqd'] as num?)?.toInt() ?? 0;
      final walletConfig = await _fetchWalletConfig();
      final minBalance = walletConfig.minBalanceIqd < 1
          ? 1
          : walletConfig.minBalanceIqd;
      if (walletStatus == 'blocked' ||
          walletBalance <= 0 ||
          walletBalance < minBalance) {
        throw StateError('wallet_blocked');
      }

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
        'operationalStatus': DriverOperationalStatus.available.value,
        'onlineSince': FieldValue.serverTimestamp(),
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
      'operationalStatus': DriverOperationalStatus.offline.value,
      'onlineSince': null,
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
      final isOnline = driverDoc.data()?['isOnline'] as bool? ?? false;
      await _firestore.collection('drivers').doc(driverId).update({
        'hasActiveRide': false,
        'operationalStatus': isOnline
            ? DriverOperationalStatus.available.value
            : DriverOperationalStatus.offline.value,
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
      locationSettings: LocationSettings(
        distanceFilter: MapPresenceConfig.locationPublishMinMoveMeters.round(),
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
      if (elapsed < MapPresenceConfig.locationPublishMinInterval &&
          movedMeters < MapPresenceConfig.locationPublishMinMoveMeters) {
        return;
      }
    }

    _lastLocationWriteAt = DateTime.now();
    _lastWrittenPosition = position;

    final heading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : 0.0;

    await _firestore.collection('drivers').doc(driverId).update({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'heading': heading,
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

  Future<WalletConfig> fetchWalletConfig() async {
    final doc = await _firestore.collection('config').doc('wallet').get();
    return WalletConfig.fromMap(doc.data());
  }

  Future<WalletConfig> _fetchWalletConfig() => fetchWalletConfig();

  Future<List<DriverProfile>> findDriversForRide({
    required String districtId,
    required String subDistrictId,
    required LatLng pickup,
    Set<String> excludeDriverIds = const {},
  }) async {
    final trimmedDistrict = districtId.trim();
    final trimmedSub = subDistrictId.trim();
    if (trimmedDistrict.isEmpty || trimmedSub.isEmpty) return const [];

    final walletConfig = await _fetchWalletConfig();

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

    final minBalance =
        walletConfig.minBalanceIqd < 1 ? 1 : walletConfig.minBalanceIqd;
    drivers = drivers
        .where((d) => d.walletAllowsMatchingWithMin(minBalance))
        .toList();

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
    FirebaseFunctions? functions,
    required DriverService driverService,
    CommissionService? commissionService,
    MonthlyPrizeService? monthlyPrizeService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _driverService = driverService,
        _monthlyPrizeService = monthlyPrizeService ?? MonthlyPrizeService() {
    // Optional commissionService kept so AppState call sites stay unchanged.
    // Ride earnings/commission now apply only in Cloud Functions.
    assert(commissionService == null || true);
  }

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final DriverService _driverService;
  final MonthlyPrizeService _monthlyPrizeService;

  static const _activeCustomerRideStatuses = [
    RideStatus.searching,
    RideStatus.matched,
    RideStatus.accepted,
    RideStatus.inProgress,
    RideStatus.awaitingCashPayment,
  ];

  Never _rethrowRideCallable(Object error) {
    if (error is FirebaseFunctionsException) {
      final code = error.message ?? error.code;
      throw StateError(code);
    }
    throw error;
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

    final pickupRegion = BabilRegions.resolveFromPoint(pickup);
    final resolvedDistrictId = districtId.trim().isNotEmpty
        ? districtId.trim()
        : pickupRegion.districtId;
    final resolvedSubDistrictId = subDistrictId.trim().isNotEmpty
        ? subDistrictId.trim()
        : pickupRegion.subDistrictId;

    final areaError = ServiceAreaCatalog.instance.validateForNewRide(
      districtId: resolvedDistrictId,
      subDistrictId: resolvedSubDistrictId,
      pickup: pickup,
    );
    if (areaError != null) {
      throw StateError(areaError);
    }

    try {
      final result = await _functions.httpsCallable('createRide').call({
        'pickupLabel': pickupLabel,
        'destinationLabel': destinationLabel,
        'pickupLat': pickup.latitude,
        'pickupLng': pickup.longitude,
        'destinationLat': destination.latitude,
        'destinationLng': destination.longitude,
        'districtId': resolvedDistrictId,
        'subDistrictId': resolvedSubDistrictId,
        'fareAmountIqd': fareAmountIqd,
        'distanceKm': distanceKm,
        if (originalFareIqd > 0) 'originalFareIqd': originalFareIqd,
        if (promoDiscountIqd > 0) 'promoDiscountIqd': promoDiscountIqd,
        if (promoCode.isNotEmpty) 'promoCode': promoCode,
      });
      final data = Map<String, dynamic>.from(result.data as Map? ?? {});
      final rideId = data['rideId'] as String? ?? '';
      final rideMap = Map<String, dynamic>.from(data['ride'] as Map? ?? {});
      if (rideId.isEmpty) {
        throw StateError('ride_create_failed');
      }
      if (rideMap.isNotEmpty) {
        return Ride.fromMap(rideId, rideMap);
      }
      final latest = await _firestore.collection('rides').doc(rideId).get();
      if (latest.exists && latest.data() != null) {
        return Ride.fromMap(rideId, latest.data()!);
      }
      throw StateError('ride_create_failed');
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  Future<Ride> assignNearestDriver(
    String rideId, {
    Set<String> excludeDriverIds = const {},
  }) async {
    try {
      await _functions.httpsCallable('assignNearestDriver').call({
        'rideId': rideId,
        'excludeDriverIds': excludeDriverIds.toList(),
      }).timeout(const Duration(seconds: 30));
      final latest = await _firestore.collection('rides').doc(rideId).get();
      if (latest.exists && latest.data() != null) {
        return Ride.fromMap(rideId, latest.data()!);
      }
      throw StateError('ride_not_found');
    } catch (error) {
      _rethrowRideCallable(error);
    }
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
    var walletEligible = true;
    var minBalanceIqd = 1;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? assignedSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? offeredSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subDistrictSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? driverSubscription;

    controller = StreamController<Ride?>.broadcast(
      onListen: () {
        Ride? current;

        void publish() {
          final assigned = _driverVisibleRide(assignedRide, driverId: driverId);
          // Empty/blocked wallet: hide new offers; keep already-accepted trips.
          final next = assigned ??
              (walletEligible
                  ? (_driverVisibleRide(offeredRide, driverId: driverId) ??
                      _driverVisibleRide(searchingRide, driverId: driverId))
                  : null);
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
            .listen((driverSnap) async {
          if (controller.isClosed || !driverSnap.exists) return;
          final driverData = driverSnap.data();
          if (driverData == null) return;

          try {
            final config = await _driverService.fetchWalletConfig();
            minBalanceIqd = config.minBalanceIqd < 1 ? 1 : config.minBalanceIqd;
          } catch (_) {
            minBalanceIqd = 1;
          }
          final walletStatus = driverData['walletStatus'] as String? ?? 'active';
          final walletBalance =
              (driverData['walletBalanceIqd'] as num?)?.toInt() ?? 0;
          walletEligible = walletStatus != 'blocked' &&
              walletBalance > 0 &&
              walletBalance >= minBalanceIqd;
          if (!walletEligible) {
            offeredRide = null;
            searchingRide = null;
            subDistrictSubscription?.cancel();
            subDistrictSubscription = null;
            publish();
            return;
          }

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
          publish();
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
    try {
      await _functions.httpsCallable('acceptRide').call({'rideId': rideId});
      NotificationService.clearDriverRideOffer(rideId);
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  Future<void> rejectRide({
    required String rideId,
    required String driverId,
  }) async {
    try {
      await _functions.httpsCallable('rejectRide').call({'rideId': rideId});
      NotificationService.clearDriverRideOffer(rideId);
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  Future<void> startRide(String rideId) async {
    try {
      await _functions.httpsCallable('startRide').call({'rideId': rideId});
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  Future<void> endRideAwaitingCash(String rideId) async {
    try {
      await _functions
          .httpsCallable('endRideAwaitingCash')
          .call({'rideId': rideId});
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  Future<void> confirmCashCollected(String rideId) async {
    try {
      await _functions
          .httpsCallable('confirmCashCollected')
          .call({'rideId': rideId});
      final latest = await _firestore.collection('rides').doc(rideId).get();
      final driverId = latest.data()?['driverId'] as String?;
      if (driverId != null && driverId.isNotEmpty) {
        unawaited(_monthlyPrizeService.incrementDriverMonthlyRide(driverId));
      }
    } catch (error) {
      _rethrowRideCallable(error);
    }
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
    try {
      await _functions.httpsCallable('submitDriverRating').call({
        'rideId': rideId,
        'rating': rating,
        'feedback': feedback.trim(),
      });
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  /// Applies commission split and updates driver totals for a paid ride.
  /// Safe to retry when cash was collected but earnings were not applied yet.
  Future<void> finishRideAndApplyEarnings(String rideId) async {
    try {
      await _functions.httpsCallable('applyPendingRideEarnings').call({
        'rideId': rideId,
        'limit': 1,
      });
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  /// Backfills rides where cash was collected but earnings were never applied.
  Future<int> applyPendingEarnings({int limit = 100}) async {
    try {
      final result = await _functions
          .httpsCallable('applyPendingRideEarnings')
          .call({'limit': limit});
      final data = Map<String, dynamic>.from(result.data as Map? ?? {});
      return (data['applied'] as num?)?.toInt() ?? 0;
    } catch (error) {
      _rethrowRideCallable(error);
    }
  }

  Future<void> cancelRide(
    String rideId, {
    UserRole cancelledBy = UserRole.customer,
  }) async {
    try {
      await _functions.httpsCallable('cancelRide').call({
        'rideId': rideId,
        'cancelledBy': cancelledBy.value,
      });
      NotificationService.clearDriverRideOffer(rideId);
    } catch (error) {
      _rethrowRideCallable(error);
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
