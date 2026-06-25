import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/firebase_options.dart';
import 'package:permission_handler/permission_handler.dart';

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
  });

  final RideAlertType type;
  final String title;
  final String body;
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StreamController<RideAlertEvent> _rideAlertController =
      StreamController<RideAlertEvent>.broadcast();
  static final AudioPlayer _alertPlayer = AudioPlayer();
  static StreamSubscription<Ride?>? _driverRideSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _driverOfferSubscription;
  static StreamSubscription<Ride?>? _customerRideSubscription;
  static RideStatus? _lastCustomerRideStatus;
  static final Set<String> _notifiedDriverRideIds = {};
  static final Set<String> _notifiedCustomerAcceptedRideIds = {};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _announcementSubscription;
  static var _announcementListenerReady = false;
  static var _initialized = false;
  static var _backgroundReady = false;
  static var _audioUnlocked = false;

  static const _driverChannelId = 'driver_ride_requests_v3';
  static const _customerChannelId = 'customer_ride_updates_v3';
  static const _chatChannelId = 'ride_chat_messages_v3';
  static const _announcementChannelId = 'admin_announcements';

  static const _driverSound = 'driver_ride_request';
  static const _customerSound = 'customer_ride_accepted';
  static const _chatSound = 'chat_message';

  static Stream<RideAlertEvent> get rideAlertStream =>
      _rideAlertController.stream;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
    }

    if (!kIsWeb) {
      await _requestPlatformPermissions();
      await _ensureLocalNotificationsReady(requestPermissions: true);
      await _createAndroidChannels();

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

  static Future<void> unlockAudioIfNeeded() async {
    if (_audioUnlocked) return;
    try {
      await _alertPlayer.setVolume(0.01);
      await _alertPlayer.play(AssetSource('sounds/$_driverSound.wav'));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _alertPlayer.stop();
      await _alertPlayer.setVolume(1.0);
      _audioUnlocked = true;
    } catch (_) {
      _audioUnlocked = false;
    }
  }

  static Future<void> _requestPlatformPermissions() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
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
      onDidReceiveNotificationResponse: (_) {},
    );

    _backgroundReady = true;
  }

  static Future<void> _createAndroidChannels() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _driverChannelId,
        'Driver ride requests',
        description: 'Alerts when a new ride is assigned to the driver',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_driverSound),
      ),
    );
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        _customerChannelId,
        'Customer ride updates',
        description: 'Alerts when the driver accepts your trip',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(_customerSound),
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

  static void clearDriverRideOffer(String rideId) {
    _notifiedDriverRideIds.remove(rideId);
    stopAlertSound();
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

  static void _notifyDriverRideIfNew(Ride ride) {
    final isNewMatchedRide = ride.status == RideStatus.matched &&
        !_notifiedDriverRideIds.contains(ride.id);
    if (!isNewMatchedRide) return;

    _notifiedDriverRideIds.add(ride.id);
    unawaited(unlockAudioIfNeeded());
    unawaited(_triggerRideAlert(
      type: RideAlertType.driverRideRequest,
      title: 'New ride request',
      body: '${ride.pickupLabel} → ${ride.destinationLabel}',
    ));
  }

  static void startRideAlertListeners({
    required FirebaseFirestore firestore,
    required String uid,
    required UserRole role,
  }) {
    stopRideAlertListeners();
    _lastCustomerRideStatus = null;
    _notifiedDriverRideIds.clear();
    _notifiedCustomerAcceptedRideIds.clear();

    if (role == UserRole.driver) {
      _driverOfferSubscription = firestore
          .collection('rides')
          .where('offeredDriverIds', arrayContains: uid)
          .where('status', isEqualTo: RideStatus.matched.value)
          .limit(5)
          .snapshots()
          .listen((snapshot) {
        final activeOfferIds = <String>{};
        var hasNewOffer = false;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data['driverId'] != null) continue;
          activeOfferIds.add(doc.id);
          if (!_notifiedDriverRideIds.contains(doc.id)) {
            hasNewOffer = true;
          }
          _notifyDriverRideIfNew(Ride.fromMap(doc.id, data));
        }

        final staleOffers = _notifiedDriverRideIds
            .where((rideId) => !activeOfferIds.contains(rideId))
            .toList();
        if (staleOffers.isNotEmpty && !hasNewOffer) {
          for (final rideId in staleOffers) {
            _notifiedDriverRideIds.remove(rideId);
          }
          unawaited(stopAlertSound());
        }
      });
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
    unawaited(_customerRideSubscription?.cancel());
    _driverRideSubscription = null;
    _driverOfferSubscription = null;
    _customerRideSubscription = null;
    _lastCustomerRideStatus = null;
    _notifiedDriverRideIds.clear();
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
      await _triggerRideAlert(
        type: RideAlertType.driverRideRequest,
        title: message.data['title'] ??
            message.notification?.title ??
            'New ride request',
        body: message.data['body'] ?? message.notification?.body ?? '',
        playInAppSound: playInAppSound,
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
    try {
      await _alertPlayer.stop();
    } catch (_) {}
  }

  static Future<void> _triggerRideAlert({
    required RideAlertType type,
    required String title,
    required String body,
    bool playInAppSound = true,
    bool showLocalNotification = true,
  }) async {
    _rideAlertController.add(
      RideAlertEvent(type: type, title: title, body: body),
    );

    if (!kIsWeb && showLocalNotification) {
      await _showLocalNotification(type: type, title: title, body: body);
    }

    if (playInAppSound) {
      unawaited(_playAlertSound(type));
    }
  }

  static Future<void> _showLocalNotification({
    required RideAlertType type,
    required String title,
    required String body,
  }) async {
    final isDriver = type == RideAlertType.driverRideRequest;
    final isChat = type == RideAlertType.chatMessage;
    final channelId = isDriver
        ? _driverChannelId
        : isChat
            ? _chatChannelId
            : _customerChannelId;
    final androidSound =
        isDriver ? _driverSound : isChat ? _chatSound : _customerSound;

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
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
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound(androidSound),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          category: isChat
              ? AndroidNotificationCategory.message
              : AndroidNotificationCategory.call,
          visibility: NotificationVisibility.public,
          fullScreenIntent: isDriver,
          ticker: title,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: '$androidSound.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }

  static Future<void> _playAlertSound(RideAlertType type) async {
    if (kIsWeb) return;

    final asset = switch (type) {
      RideAlertType.driverRideRequest => 'sounds/$_driverSound.wav',
      RideAlertType.customerRideAccepted => 'sounds/$_customerSound.wav',
      RideAlertType.chatMessage => 'sounds/$_chatSound.wav',
    };
    final repeats = switch (type) {
      RideAlertType.driverRideRequest => 6,
      RideAlertType.customerRideAccepted => 3,
      RideAlertType.chatMessage => 2,
    };
    final loopUntilStopped = type == RideAlertType.driverRideRequest;

    try {
      await HapticFeedback.heavyImpact();
      await _alertPlayer.stop();
      await _alertPlayer.setReleaseMode(
        loopUntilStopped ? ReleaseMode.loop : ReleaseMode.stop,
      );
      await _alertPlayer.setVolume(1.0);
      await _alertPlayer.play(AssetSource(asset));

      if (loopUntilStopped) {
        return;
      }

      for (var i = 0; i < repeats - 1; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        await _alertPlayer.stop();
        await _alertPlayer.play(AssetSource(asset));
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _alertPlayer.stop();
    } catch (error) {
      debugPrint('Ride alert sound failed: $error');
      for (var i = 0; i < repeats; i++) {
        await SystemSound.play(SystemSoundType.alert);
        if (i + 1 < repeats) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
        }
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final type = message.data['type'];
  final isRideAlert = type == 'ride_matched' || type == 'ride_accepted';

  if (!isRideAlert && message.notification != null) return;

  await NotificationService._ensureLocalNotificationsReady(
    requestPermissions: false,
  );
  await NotificationService._createAndroidChannels();

  final hasSystemNotification = message.notification != null;

  if (type == 'ride_matched') {
    await NotificationService._triggerRideAlert(
      type: RideAlertType.driverRideRequest,
      title: message.data['title'] ?? 'New ride request',
      body: message.data['body'] ?? '',
      playInAppSound: false,
      showLocalNotification: !hasSystemNotification,
    );
    return;
  }

  if (type == 'ride_accepted') {
    await NotificationService._triggerRideAlert(
      type: RideAlertType.customerRideAccepted,
      title: message.data['title'] ?? 'Driver accepted',
      body: message.data['body'] ?? 'Your driver is on the way',
      playInAppSound: false,
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
