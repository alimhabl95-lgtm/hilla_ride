import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final _picker = ImagePicker();
  static const _maxPhotoBytes = 15 * 1024 * 1024;
  static const _maxVoiceBytes = 5 * 1024 * 1024;

  Reference _driverPhotoRef({
    required String driverId,
    required String fileName,
  }) {
    return _storage.ref().child('driver_applications/$driverId/$fileName');
  }

  Reference _userPhotoRef(String userId) {
    return _storage.ref().child('user_profiles/$userId/profile_photo.jpg');
  }

  Future<String> uploadUserProfilePhoto({
    required String uid,
    required Uint8List bytes,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'Sign in again to upload your profile photo.',
      );
    }

    if (bytes.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Photo file is empty.',
      );
    }

    final ref = _userPhotoRef(currentUid);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String> uploadRideVoiceMessage({
    required String rideId,
    required String messageId,
    required Uint8List bytes,
    String fileExtension = 'm4a',
    String contentType = 'audio/mp4',
  }) async {
    if (_auth.currentUser == null) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'Sign in again to send voice messages.',
      );
    }

    if (bytes.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Voice recording is empty.',
      );
    }

    if (bytes.length > _maxVoiceBytes) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Voice message is too long.',
      );
    }

    final ref = _storage.ref().child('ride_chat/$rideId/$messageId.$fileExtension');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  Future<Uint8List?> downloadRideVoiceMessage({
    required String voiceUrl,
    int maxBytes = _maxVoiceBytes,
  }) async {
    if (_auth.currentUser == null) return null;
    if (voiceUrl.trim().isEmpty) return null;

    try {
      final ref = _storage.refFromURL(voiceUrl);
      final data = await ref.getData(maxBytes);
      if (data != null && data.isNotEmpty) {
        return data;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Voice download failed: $error');
      }
    }

    return null;
  }

  Future<XFile?> pickImage(ImageSource source) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  }

  Future<String> uploadDriverDocument({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ref = _driverPhotoRef(driverId: uid, fileName: fileName);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<String?> resolveDriverPhotoUrl({
    required String driverId,
    required String fileName,
    String imageUrl = '',
  }) async {
    if (_auth.currentUser == null) {
      if (kDebugMode) {
        debugPrint('Driver photo load blocked: user is not signed in.');
      }
      return null;
    }

    final ref = _driverPhotoRef(driverId: driverId, fileName: fileName);

    try {
      return await ref.getDownloadURL();
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Driver photo path load failed for $driverId/$fileName: $error',
        );
      }
    }

    if (imageUrl.isNotEmpty) {
      try {
        final urlRef = _storage.refFromURL(imageUrl);
        return await urlRef.getDownloadURL();
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Driver photo URL refresh failed: $error');
        }
        return imageUrl;
      }
    }

    return null;
  }

  Future<Uint8List?> loadDriverPhotoBytes({
    required String driverId,
    required String fileName,
    String imageUrl = '',
  }) async {
    if (_auth.currentUser == null) {
      if (kDebugMode) {
        debugPrint('Driver photo bytes blocked: user is not signed in.');
      }
      return null;
    }

    final ref = _driverPhotoRef(driverId: driverId, fileName: fileName);

    try {
      final data = await ref.getData(_maxPhotoBytes);
      if (data != null && data.isNotEmpty) {
        return data;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Driver photo getData failed for $driverId/$fileName: $error',
        );
      }
    }

    if (imageUrl.isNotEmpty) {
      try {
        final urlRef = _storage.refFromURL(imageUrl);
        final data = await urlRef.getData(_maxPhotoBytes);
        if (data != null && data.isNotEmpty) {
          return data;
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Driver photo getData from stored URL failed: $error');
        }
      }
    }

    final url = await resolveDriverPhotoUrl(
      driverId: driverId,
      fileName: fileName,
      imageUrl: imageUrl,
    );
    if (url == null || url.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Driver photo HTTP load failed: $error');
      }
    }

    return null;
  }
}
