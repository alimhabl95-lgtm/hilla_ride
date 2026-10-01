import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hilla_ride/core/config/firebase_config.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/services/driver_ride_alert_settings.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RideAlertType {
  driverRideRequest,
  customerRideAccepted,
  chatMessage,
}

class RideAlertEvent {
  const RideAlertEvent({
    required this.type,
    required this.title,
    required this.body,
    this.rideId,
  });

  final RideAlertType type;
  final String title;
  final String body;
  final String? rideId;
}

/// Notifies listeners again when the same ride offer is published twice.
class RideOfferSignal extends ValueNotifier<String?> {
  RideOfferSignal() : super(null);

  void republish(String rideId) {
    if (value == rideId) {
      notifyListeners();
    } else {
      value = rideId;
    }
  }
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StreamController<RideAlertEvent> _rideAlertController =
      StreamController<RideAlertEvent>.broadcast();
  static Timer? _alertSoundTimer;
  static Timer? _alertSoundStopTimer;

  /// Driver ride alert plays for this long, then stops on its own.
  static const _driverAlertSoundDuration = Duration(seconds: 3);
  static StreamSubscription<Ride?>? _driverRideSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _driverOfferSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _driverDistrictOfferSubscription;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _driverProfileSubscription;
  static String _driverSubDistrictId = '';
  static String _driverAlertUid = '';
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _pendingOfferRideSubscription;
  static String? _watchedPendingOfferRideId;
  static StreamSubscription<Ride?>? _customerRideSubscription;
  static RideStatus? _lastCustomerRideStatus;
  static final Set<String> _notifiedDriverRideIds = {};
  static final Set<String> _suppressedDriverRideIds = {};
  static final Set<String> _notifiedCustomerAcceptedRideIds = {};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _announcementSubscription;
  static var _announcementListenerReady = false;
  static var _initialized = false;
  static var _backgroundReady = false;
  static var _audioUnlocked = false;
  static var _alertSoundLoopActive = false;
  static AudioPlayer? _rideAlertPlayer;

  static var _alertListenGeneration = 0;

  static const _driverChannelTone1 = 'driver_ride_requests_v11_tone1';
  static const _driverChannelTone2 = 'driver_ride_requests_v11_tone2';
  static const _customerChannelId = 'customer_ride_updates_v4';
  static const _chatChannelId = 'ride_chat_messages_v3';
  static const _announcementChannelId = 'admin_announcements';

  /// Shared iPhone-style Chord chime for driver + customer ride alerts.
  static const _rideAlertSound = 'ride_alert_loud';
  static const _chatSound = 'chat_message';
  static const _rideAlertChannel = MethodChannel('hilla_ride/ride_alert');
  static final Int64List _rideShakePattern = Int64List.fromList(
    [0, 400, 120, 400, 120, 400, 120, 600, 150, 700],
  );
  static const _driverRideNotificationId = 74001;

  static final RideOfferSignal pendingDriverOfferId = RideOfferSignal();
  static Ride? pendingDriverOfferRide;

  /// After Accept on Android, show active ride UI before Firestore catches up.
  static final ValueNotifier<String?> androidOptimisticActiveRideId =
      ValueNotifier<String?>(null);

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool isAndroidOptimisticActive(String? rideId) {
    if (rideId == null || rideId.isEmpty) return false;
    return isAndroid && androidOptimisticActiveRideId.value == rideId;
  }

  static void markAndroidDriverAccepted(String rideId) {
    if (!isAndroid || rideId.isEmpty) return;
    clearDriverRideOffer(rideId);
    androidOptimisticActiveRideId.value = rideId;
  }

  static void syncAndroidOptimisticActiveRide(Ride? ride) {
    if (!isAndroid) return;
    final optimisticId = androidOptimisticActiveRideId.value;
    if (optimisticId == null) return;
    if (ride == null || ride.id != optimisticId) return;
    switch (ride.status) {
      case RideStatus.accepted:
      case RideStatus.inProgress:
      case RideStatus.awaitingCashPayment:
        androidOptimisticActiveRideId.value = null;
      default:
        break;
    }
  }

  static Stream<RideAlertEvent> get rideAlertStream =>
      _rideAlertController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await _requestPlatformPermissions();
      await _ensureLocalNotificationsReady(requestPermissions: true);
      await _createAndroidChannels();
      if (isAndroid) {
        await AudioPlayer.global.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.alarm,
              audioFocus: AndroidAudioFocus.gain,
            ),
          ),
        );
      }

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
      unawaited(_handleInitialMessage());
    }
  }

  static Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      await _dispatchRemoteAlert(message, playInAppSound: false);
    }
  }

  @pragma('vm:entry-point')
  static void _onLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload?.trim();
    if (payload == null || payload.isEmpty) return;
    unawaited(_openOfferIfInArea(payload));
    unawaited(stopAlertSound());
  }

  /// Re-check notification + full-screen intent (e.g. when driver goes online).
  static Future<void> ensureAndroidAlertPermissions() async {
    if (!isAndroid) return;
    await Permission.notification.request();
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  static Future<void> unlockAudioIfNeeded() async {
    if (_audioUnlocked) return;
    try {
      await SystemSound.play(SystemSoundType.click);
      _audioUnlocked = true;
    } catch (_) {
      _audioUnlocked = false;
    }
  }

  static Future<void> _requestPlatformPermissions() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestFullScreenIntentPermission();
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _ensureLocalNotificationsReady({
    required bool requestPermissions,
  }) async {
    if (_backgroundReady && !requestPermissions) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: requestPermissions,
      requestBadgePermission: requestPermissions,
      requestSoundPermission: requestPermissions,
    );

    await _localNotifications.initialize(
      InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onLocalNotificationResponse,
    );

    _backgroundReady = true;
  }

  static Future<void> _createAndroidChannels() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _driverChannelTone1,
        'Driver ride requests',
        description: 'Sound and vibration when a new ride arrives',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('ride_alert_loud'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        bypassDnd: true,
        showBadge: true,
        enableLights: true,
        ledColor: Color(0xFF0E948C),
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _driverChannelTone2,
        'Driver ride requests tone 2',
        description: 'Alternate tone when a new ride arrives',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('ride_alert_chord'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        bypassDnd: true,
        showBadge: true,
        enableLights: true,
        ledColor: Color(0xFF0E948C),
      ),
    );
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _customerChannelId,
        'Customer ride updates',
        description: 'Alerts when the driver accepts your trip',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _rideShakePattern,
        sound: RawResourceAndroidNotificationSound(_rideAlertSound),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _chatChannelId,
        'Ride chat messages',
        description: 'Alerts for new chat messages during a ride',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_chatSound),
      ),
    );
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _announcementChannelId,
        'Announcements',
        description: 'Important messages from Hello Tuk-Tuk',
        importance: Importance.high,
        playSound: true,
      ),
    );
  }

  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    return _messaging.getToken();
  }

  static Stream<String> tokenRefresh() => _messaging.onTokenRefresh;

  static Future<void> saveTokenForUser({
    required FirebaseFirestore firestore,
    required String uid,
    required UserRole role,
    required String token,
  }) async {
    final collection = role == UserRole.driver ? 'drivers' : 'users';
    await firestore.collection(collection).doc(uid).set(
      {'fcmToken': token, 'fcmUpdatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  static void notifyDriverRideIfNew(Ride ride) => _notifyDriverRideIfNew(ride);

  static bool wasDriverOfferSuppressed(String rideId) =>
      _suppressedDriverRideIds.contains(rideId);

  static String _suppressedPrefsKey(String uid) => 'driver_suppressed_rides_$uid';

  static Future<void> _loadSuppressedOffersForDriver(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_suppressedPrefsKey(uid)) ?? const [];
      _suppressedDriverRideIds.addAll(stored);
      _notifiedDriverRideIds.addAll(stored);
    } catch (error) {
      debugPrint('load suppressed offers failed: $error');
    }
  }

  static Future<void> _persistSuppressedOffer(String uid, String rideId) async {
    if (uid.isEmpty || rideId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _suppressedPrefsKey(uid);
      final stored = prefs.getStringList(key)?.toSet() ?? <String>{};
      stored.add(rideId);
      if (stored.length > 200) {
        final trimmed = stored.toList()..sort();
        stored
          ..clear()
          ..addAll(trimmed.skip(trimmed.length - 200));
      }
      await prefs.setStringList(key, stored.toList());
    } catch (error) {
      debugPrint('persist suppressed offer failed: $error');
    }
  }

  static void suppressDriverRideOffer(String rideId) {
    if (rideId.isEmpty) return;
    _suppressedDriverRideIds.add(rideId);
    _notifiedDriverRideIds.add(rideId);
    final uid = _driverAlertUid.trim().isNotEmpty
        ? _driverAlertUid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    unawaited(_persistSuppressedOffer(uid, rideId));
    clearDriverRideOffer(rideId);
  }

  static void clearDriverRideOffer(String rideId) {
    if (pendingDriverOfferId.value == rideId) {
      pendingDriverOfferId.value = null;
      pendingDriverOfferRide = null;
    }
    _stopWatchingPendingOfferRide(rideId);
    stopAlertSound();
    if (isAndroid) {
      unawaited(_localNotifications.cancel(_driverRideNotificationId));
    }
  }

  static void _stopWatchingPendingOfferRide([String? rideId]) {
    if (rideId != null &&
        _watchedPendingOfferRideId != null &&
        _watchedPendingOfferRideId != rideId) {
      return;
    }
    unawaited(_pendingOfferRideSubscription?.cancel());
    _pendingOfferRideSubscription = null;
    _watchedPendingOfferRideId = null;
  }

  static void _watchPendingOfferRide(String rideId) {
    if (rideId.isEmpty) return;
    if (_watchedPendingOfferRideId == rideId) return;
    _stopWatchingPendingOfferRide();
    _watchedPendingOfferRideId = rideId;
    final uid = _driverAlertUid;
    _pendingOfferRideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) {
          clearDriverRideOffer(rideId);
          return;
        }
        final data = snapshot.data();
        if (data == null) {
          clearDriverRideOffer(rideId);
          return;
        }
        final status =
            RideStatusX.fromString(data['status'] as String?);
        if (status == RideStatus.cancelled) {
          clearDriverRideOffer(rideId);
          return;
        }
        final assigned = data['driverId'];
        final takenByOther = assigned is String &&
            assigned.trim().isNotEmpty &&
            uid.isNotEmpty &&
            assigned != uid;
        if (takenByOther &&
            (status == RideStatus.accepted ||
                status == RideStatus.inProgress ||
                status == RideStatus.awaitingCashPayment ||
                status == RideStatus.completed)) {
          clearDriverRideOffer(rideId);
          return;
        }
        final rejected = (data['rejectedDriverIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        if (uid.isNotEmpty && rejected.contains(uid)) {
          clearDriverRideOffer(rideId);
          return;
        }
        final rideSub = (data['subDistrictId'] as String?)?.trim() ?? '';
        if (_driverSubDistrictId.isNotEmpty &&
            (rideSub.isEmpty || rideSub != _driverSubDistrictId)) {
          clearDriverRideOffer(rideId);
        }
      },
      onError: (Object error) {
        debugPrint('pending offer ride watch error: $error');
      },
    );
  }

  static void setPendingDriverOffer(Ride ride) {
    pendingDriverOfferRide = ride;
    pendingDriverOfferId.republish(ride.id);
    _watchPendingOfferRide(ride.id);
  }

  /// Surfaces an incoming offer for the driver home + alert "Open request" path.
  static void presentDriverOffer(String rideId, {Ride? ride}) {
    if (rideId.isEmpty) return;
    if (ride != null && ride.id == rideId) {
      pendingDriverOfferRide = ride;
    }
    pendingDriverOfferId.republish(rideId);
    _watchPendingOfferRide(rideId);
  }

  static Future<void> notifyChatMessage({
    required String title,
    required String body,
  }) {
    return _triggerRideAlert(
      type: RideAlertType.chatMessage,
      title: title,
      body: body,
    );
  }

  static void notifyCustomerRideAccepted(Ride ride) {
    if (ride.status != RideStatus.accepted ||
        _notifiedCustomerAcceptedRideIds.contains(ride.id)) {
      return;
    }
    _notifiedCustomerAcceptedRideIds.add(ride.id);
    unawaited(_triggerRideAlert(
      type: RideAlertType.customerRideAccepted,
      title: 'Driver accepted',
      body: 'Your driver is on the way',
    ));
  }

  static bool _markRideAlerted(String rideId) {
    if (rideId.isEmpty) return false;
    if (_suppressedDriverRideIds.contains(rideId)) return false;
    if (_notifiedDriverRideIds.contains(rideId)) return false;
    _notifiedDriverRideIds.add(rideId);
    final uid = _driverAlertUid.trim().isNotEmpty
        ? _driverAlertUid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    unawaited(_persistAlertedRide(uid, rideId));
    return true;
  }

  static Future<void> _loadAlertedRides(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('driver_alerted_rides_$uid') ?? const [];
      _notifiedDriverRideIds.addAll(stored);
    } catch (error) {
      debugPrint('load alerted rides failed: $error');
    }
  }

  static Future<void> _persistAlertedRide(String uid, String rideId) async {
    if (uid.isEmpty || rideId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'driver_alerted_rides_$uid';
      final stored = prefs.getStringList(key)?.toSet() ?? <String>{};
      stored.add(rideId);
      if (stored.length > 200) {
        final trimmed = stored.toList();
        stored
          ..clear()
          ..addAll(trimmed.skip(trimmed.length - 200));
      }
      await prefs.setStringList(key, stored.toList());
    } catch (error) {
      debugPrint('persist alerted ride failed: $error');
    }
  }

  /// Background isolate: one alert per ride, even if FCM is delivered twice.
  static Future<bool> claimBackgroundRideAlert(String rideId) async {
    if (rideId.isEmpty) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          prefs.getStringList('driver_alerted_rides_$uid') ?? const <String>[];
      if (stored.contains(rideId)) return false;
    }
    return _markRideAlerted(rideId);
  }

  static void _notifyDriverRideIfNew(Ride ride) {
    if (ride.status != RideStatus.matched) return;
    if (!_markRideAlerted(ride.id)) return;

    setPendingDriverOffer(ride);
    unawaited(unlockAudioIfNeeded());
    unawaited(_triggerRideAlert(
      type: RideAlertType.driverRideRequest,
      title: 'New ride request',
      body: '${ride.pickupLabel} → ${ride.destinationLabel}',
      rideId: ride.id,
    ));
  }

  static Future<void> _startDriverOfferWatch(
    FirebaseFirestore firestore,
    String uid,
    int generation,
  ) async {
    await _loadSuppressedOffersForDriver(uid);
    await _loadAlertedRides(uid);
    if (generation != _alertListenGeneration || _driverAlertUid != uid) return;

    void handleOfferDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
      for (final doc in docs) {
        final data = doc.data();
        final assigned = data['driverId'];
        if (assigned is String && assigned.trim().isNotEmpty) continue;
        final offered = (data['offeredDriverIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        if (!offered.contains(uid)) continue;
        final rideSub = (data['subDistrictId'] as String?)?.trim() ?? '';
        if (rideSub.isEmpty ||
            _driverSubDistrictId.isEmpty ||
            rideSub != _driverSubDistrictId) {
          continue;
        }
        final rejected = (data['rejectedDriverIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        if (rejected.contains(uid)) continue;
        if (_suppressedDriverRideIds.contains(doc.id)) continue;
        _notifyDriverRideIfNew(Ride.fromMap(doc.id, data));
      }
    }

    _driverOfferSubscription = firestore
        .collection('rides')
        .where('offeredDriverIds', arrayContains: uid)
        .where('status', isEqualTo: RideStatus.matched.value)
        .limit(5)
        .snapshots()
        .listen(
      (snapshot) => handleOfferDocs(snapshot.docs),
      onError: (Object error) {
        debugPrint('driver offer notification listen error: $error');
      },
    );

    _driverProfileSubscription =
        firestore.collection('drivers').doc(uid).snapshots().listen(
      (snapshot) {
        final data = snapshot.data();
        _driverSubDistrictId =
            (data?['assignedSubDistrictId'] as String?)?.trim() ?? '';
      },
      onError: (Object error) {
        debugPrint('driver profile notification listen error: $error');
      },
    );
  }

  static void startRideAlertListeners({
    required FirebaseFirestore firestore,
    required String uid,
    required UserRole role,
  }) {
    stopRideAlertListeners();
    _lastCustomerRideStatus = null;
    _notifiedCustomerAcceptedRideIds.clear();

    if (role == UserRole.driver) {
      final generation = ++_alertListenGeneration;
      _driverAlertUid = uid;
      unawaited(_startDriverOfferWatch(firestore, uid, generation));
      return;
    }

    if (role == UserRole.customer) {
      _customerRideSubscription = firestore
          .collection('rides')
          .where('customerId', isEqualTo: uid)
          .where('status', whereIn: [
            RideStatus.matched.value,
            RideStatus.accepted.value,
            RideStatus.inProgress.value,
            RideStatus.awaitingCashPayment.value,
          ])
          .limit(1)
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        return Ride.fromMap(doc.id, doc.data());
      }).listen((ride) {
        if (ride == null) {
          _lastCustomerRideStatus = null;
          return;
        }

        final previousStatus = _lastCustomerRideStatus;
        _lastCustomerRideStatus = ride.status;

        final acceptedNow = ride.status == RideStatus.accepted &&
            !_notifiedCustomerAcceptedRideIds.contains(ride.id) &&
            (previousStatus != RideStatus.accepted || previousStatus == null);
        if (acceptedNow) {
          _notifiedCustomerAcceptedRideIds.add(ride.id);
          unawaited(_triggerRideAlert(
            type: RideAlertType.customerRideAccepted,
            title: 'Driver accepted',
            body: 'Your driver is on the way',
          ));
        }
      });
    }
  }

  static void stopRideAlertListeners() {
    unawaited(_driverRideSubscription?.cancel());
    unawaited(_driverOfferSubscription?.cancel());
    unawaited(_driverDistrictOfferSubscription?.cancel());
    unawaited(_driverProfileSubscription?.cancel());
    unawaited(_customerRideSubscription?.cancel());
    _stopWatchingPendingOfferRide();
    _driverRideSubscription = null;
    _driverOfferSubscription = null;
    _driverDistrictOfferSubscription = null;
    _driverProfileSubscription = null;
    _driverSubDistrictId = '';
    _driverAlertUid = '';
    _customerRideSubscription = null;
    _lastCustomerRideStatus = null;
    _notifiedCustomerAcceptedRideIds.clear();
  }

  static void stopAnnouncementListener() {
    unawaited(_announcementSubscription?.cancel());
    _announcementSubscription = null;
    _announcementListenerReady = false;
  }

  static void startAnnouncementListener({
    required FirebaseFirestore firestore,
    required String audience,
  }) {
    if (kIsWeb) return;

    _announcementSubscription?.cancel();
    _announcementListenerReady = false;

    _announcementSubscription = firestore
        .collection('announcements')
        .where('audience', isEqualTo: audience)
        .limit(12)
        .snapshots()
        .listen((snapshot) {
      if (!_announcementListenerReady) {
        _announcementListenerReady = true;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        unawaited(
          _showAnnouncementNotification(
            title: data['title'] as String? ?? 'Announcement',
            body: data['body'] as String? ?? '',
          ),
        );
      }
    });
  }

  /// Offer popup only when this driver's approved ناحية matches the pickup.
  static Future<Ride?> _rideIfInDriverArea(String rideId) async {
    if (rideId.isEmpty) return null;
    final storedUid = _driverAlertUid.trim();
    final uid = storedUid.isNotEmpty
        ? storedUid
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    if (uid.isEmpty) return null;
    try {
      final rideSnap = await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .get()
          .timeout(const Duration(seconds: 8));
      final driverSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final data = rideSnap.data();
      final driver = driverSnap.data();
      if (!rideSnap.exists || data == null || driver == null) return null;
      final rideSub = (data['subDistrictId'] as String?)?.trim() ?? '';
      final driverSub =
          (driver['assignedSubDistrictId'] as String?)?.trim() ?? '';
      if (rideSub.isEmpty || driverSub.isEmpty || rideSub != driverSub) {
        return null;
      }
      final offered = (data['offeredDriverIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (!offered.contains(uid)) return null;
      final assigned = data['driverId'];
      if (assigned is String && assigned.trim().isNotEmpty) return null;
      if (data['status'] != RideStatus.matched.value) return null;
      final rejected = (data['rejectedDriverIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (rejected.contains(uid)) return null;
      _driverSubDistrictId = driverSub;
      return Ride.fromMap(rideSnap.id, data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _openOfferIfInArea(String rideId) async {
    final ride = await _rideIfInDriverArea(rideId);
    if (ride == null) {
      clearDriverRideOffer(rideId);
      return;
    }
    setPendingDriverOffer(ride);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _dispatchRemoteAlert(message);
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    await _dispatchRemoteAlert(message, playInAppSound: false);
  }

  static Future<void> _dispatchRemoteAlert(
    RemoteMessage message, {
    bool playInAppSound = true,
  }) async {
    final type = message.data['type'];
    if (type == 'ride_matched') {
      final rideId = message.data['rideId'] as String?;
      if (rideId == null || rideId.isEmpty) return;
      final ride = await _rideIfInDriverArea(rideId);
      if (ride == null) return;
      if (!_markRideAlerted(rideId)) return;
      setPendingDriverOffer(ride);
      await _triggerRideAlert(
        type: RideAlertType.driverRideRequest,
        title: message.data['title'] ??
            message.notification?.title ??
            'New ride request',
        body: message.data['body'] ?? message.notification?.body ?? '',
        playInAppSound: playInAppSound,
        showLocalNotification: true,
        rideId: rideId,
      );
      return;
    }

    if (type == 'ride_accepted') {
      await _triggerRideAlert(
        type: RideAlertType.customerRideAccepted,
        title: message.data['title'] ??
            message.notification?.title ??
            'Driver accepted',
        body: message.data['body'] ??
            message.notification?.body ??
            'Your driver is on the way',
        playInAppSound: playInAppSound,
      );
      return;
    }

    if (type == 'admin_broadcast') {
      await _showAnnouncementNotification(
        title: message.notification?.title ?? 'Announcement',
        body: message.notification?.body ?? '',
      );
    }
  }

  static Future<void> _showAnnouncementNotification({
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    await _localNotifications.show(
      99,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _announcementChannelId,
          'Announcements',
          channelDescription: 'Important messages from Hello Tuk-Tuk',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> stopAlertSound() async {
    _alertSoundLoopActive = false;
    _alertSoundTimer?.cancel();
    _alertSoundTimer = null;
    _alertSoundStopTimer?.cancel();
    _alertSoundStopTimer = null;
    if (isAndroid) {
      try {
        await _rideAlertChannel.invokeMethod<void>('stopLoudAlarm');
      } catch (_) {}
    }
    try {
      await _rideAlertPlayer?.stop();
    } catch (_) {}
  }

  static Future<void> _triggerRideAlert({
    required RideAlertType type,
    required String title,
    required String body,
    bool playInAppSound = true,
    bool showLocalNotification = true,
    String? rideId,
  }) async {
    _rideAlertController.add(
      RideAlertEvent(
        type: type,
        title: title,
        body: body,
        rideId: rideId,
      ),
    );

    if (playInAppSound) {
      await _playAlertSound(type);
    }

    if (!kIsWeb && showLocalNotification) {
      await _showLocalNotification(
        type: type,
        title: title,
        body: body,
        rideId: rideId,
      );
    }
  }

  static Future<void> _showLocalNotification({
    required RideAlertType type,
    required String title,
    required String body,
    String? rideId,
  }) async {
    final settings = await DriverRideAlertSettings.load();
    final isDriver = type == RideAlertType.driverRideRequest;
    final isChat = type == RideAlertType.chatMessage;
    final channelId = isDriver
        ? (settings.tone == RideAlertTone.tone2
            ? _driverChannelTone2
            : _driverChannelTone1)
        : isChat
            ? _chatChannelId
            : _customerChannelId;
    final androidSound = isChat ? _chatSound : settings.androidSoundName;
    final playSound = isDriver ? settings.soundEnabled : true;
    final vibrate = isDriver ? settings.vibrationEnabled : true;

    final appInForeground = WidgetsBinding.instance.lifecycleState ==
        AppLifecycleState.resumed;
    if (isDriver && isAndroid && appInForeground) {
      await _localNotifications.cancel(_driverRideNotificationId);
      return;
    }
    if (isDriver && isAndroid) {
      await _localNotifications.cancel(_driverRideNotificationId);
    }
    final notificationId = isDriver
        ? _driverRideNotificationId
        : DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          isDriver
              ? 'Driver ride requests'
              : isChat
                  ? 'Ride chat messages'
                  : 'Customer ride updates',
          channelDescription: body,
          importance: Importance.max,
          priority: Priority.max,
          playSound: playSound,
          enableVibration: vibrate,
          vibrationPattern: !vibrate || isChat ? null : _rideShakePattern,
          enableLights: true,
          sound: RawResourceAndroidNotificationSound(androidSound),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: isChat
              ? AndroidNotificationCategory.message
              : AndroidNotificationCategory.navigation,
          visibility: NotificationVisibility.public,
          fullScreenIntent: false,
          ticker: title,
          ongoing: false,
          autoCancel: true,
          onlyAlertOnce: true,
          channelAction: AndroidNotificationChannelAction.createIfNotExists,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: '$androidSound.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: isDriver && rideId != null && rideId.isNotEmpty ? rideId : null,
    );
  }

  static Future<void> previewRideAlert(DriverRideAlertSettings settings) async {
    await stopAlertSound();
    _alertSoundLoopActive = true;
    try {
      await unlockAudioIfNeeded();
      await _playSelectedTone(settings);
      if (settings.vibrationEnabled) {
        await _startRideShake();
      }
    } catch (_) {}
    _alertSoundStopTimer = Timer(_driverAlertSoundDuration, () {
      unawaited(stopAlertSound());
    });
  }

  static Future<void> _playSelectedTone(DriverRideAlertSettings settings) async {
    if (isAndroid) {
      try {
        await _rideAlertChannel.invokeMethod<void>('playLoudAlarm', {
          'tone': settings.toneId,
          'volume': settings.volumeLevel,
        });
        return;
      } catch (_) {}
    }
    _rideAlertPlayer ??= AudioPlayer();
    await _rideAlertPlayer!.setReleaseMode(ReleaseMode.loop);
    try {
      await _rideAlertPlayer!.setVolume(settings.volumeLevel);
      await _rideAlertPlayer!.play(
        AssetSource(settings.assetPath),
        volume: settings.volumeLevel,
      );
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  static Future<void> _startRideShake() async {
    Future<void> pulse() async {
      try {
        await HapticFeedback.vibrate();
      } catch (_) {
        try {
          await HapticFeedback.heavyImpact();
        } catch (_) {}
      }
    }

    await pulse();
    _alertSoundTimer?.cancel();
    _alertSoundTimer = Timer.periodic(const Duration(milliseconds: 280), (_) {
      if (!_alertSoundLoopActive) return;
      unawaited(pulse());
    });
  }

  static Future<void> _playAlertSound(RideAlertType type) async {
    if (kIsWeb) return;

    if (type == RideAlertType.chatMessage) {
      await stopAlertSound();
      try {
        await HapticFeedback.mediumImpact();
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
      return;
    }

    await stopAlertSound();
    final settings = await DriverRideAlertSettings.load();
    final isDriverRequest = type == RideAlertType.driverRideRequest;
    if (isDriverRequest && !settings.soundEnabled && !settings.vibrationEnabled) {
      return;
    }
    _alertSoundLoopActive = true;
    try {
      await unlockAudioIfNeeded();
      if (!isDriverRequest || settings.soundEnabled) {
        await _playSelectedTone(settings);
      }
      if (!isDriverRequest || settings.vibrationEnabled) {
        await _startRideShake();
      }
    } catch (_) {}
    _alertSoundStopTimer = Timer(_driverAlertSoundDuration, () {
      unawaited(stopAlertSound());
    });
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseConfig.ensureInitialized();

  final type = message.data['type'];
  final isRideAlert = type == 'ride_matched' || type == 'ride_accepted';

  if (!isRideAlert && message.notification != null) return;

  await NotificationService._ensureLocalNotificationsReady(
    requestPermissions: false,
  );
  await NotificationService._createAndroidChannels();

  final hasSystemNotification = message.notification != null;

  if (type == 'ride_matched') {
    final rideId = message.data['rideId'] as String?;
    if (rideId == null || rideId.isEmpty) return;
    final ride = await NotificationService._rideIfInDriverArea(rideId);
    if (ride == null) return;
    if (!await NotificationService.claimBackgroundRideAlert(rideId)) return;
    await NotificationService._triggerRideAlert(
      type: RideAlertType.driverRideRequest,
      title: message.data['title'] ?? 'New ride request',
      body: message.data['body'] ?? '',
      playInAppSound: NotificationService.isAndroid,
      showLocalNotification: true,
      rideId: rideId,
    );
    return;
  }

  if (type == 'ride_accepted') {
    await NotificationService._triggerRideAlert(
      type: RideAlertType.customerRideAccepted,
      title: message.data['title'] ?? 'Driver accepted',
      body: message.data['body'] ?? 'Your driver is on the way',
      playInAppSound: NotificationService.isAndroid,
      showLocalNotification: !hasSystemNotification,
    );
    return;
  }

  if (type == 'admin_broadcast') {
    await NotificationService._showAnnouncementNotification(
      title: message.notification?.title ??
          message.data['title'] ??
          'Announcement',
      body: message.notification?.body ?? message.data['body'] ?? '',
    );
  }
}
