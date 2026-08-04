import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class StorageService {
  StorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
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
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid != uid) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
        message: 'Sign in again to upload your documents.',
      );
    }

    if (bytes.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Photo file is empty.',
      );
    }

    if (bytes.length > _maxPhotoBytes) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-argument',
        message: 'Photo is too large. Choose a smaller image.',
      );
    }

    await _auth.currentUser?.getIdToken(true);

    try {
      final ref = _driverPhotoRef(driverId: uid, fileName: fileName);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return ref.getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code == 'unauthorized' ||
          error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        return _uploadDriverDocumentViaFunction(
          fileName: fileName,
          bytes: bytes,
        );
      }
      rethrow;
    }
  }

  Future<String> _uploadDriverDocumentViaFunction({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await _functions
        .httpsCallable('uploadDriverApplicationPhoto')
        .call({
      'fileName': fileName,
      'base64': base64Encode(bytes),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final url = data['url'] as String? ?? '';
    if (url.isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unavailable',
        message: 'Could not upload photo. Try again.',
      );
    }
    return url;
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
    bool forAdmin = false,
  }) async {
    if (forAdmin || kIsWeb) {
      try {
        final result =
            await _functions.httpsCallable('getDriverPhotoForAdmin').call({
          'driverId': driverId,
          'fileName': fileName,
        });
        final data = Map<String, dynamic>.from(result.data as Map);
        final base64 = data['base64'] as String? ?? '';
        if (base64.isNotEmpty) {
          return base64Decode(base64);
        }
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'not-found' && kDebugMode) {
          debugPrint('Admin photo cloud load failed: ${error.message}');
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Admin photo cloud load failed: $error');
        }
      }
    }

    if (imageUrl.isNotEmpty && kIsWeb) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Driver photo HTTP load failed for stored URL: $error');
        }
      }
    }

    if (_auth.currentUser == null) {
      if (kDebugMode) {
        debugPrint('Driver photo load blocked: user is not signed in.');
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

    if (imageUrl.isNotEmpty && !kIsWeb) {
      try {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Driver photo HTTP load failed for stored URL: $error');
        }
      }
    }

    try {
      final freshUrl = await ref.getDownloadURL();
      if (freshUrl.isNotEmpty && !kIsWeb) {
        final response = await http.get(Uri.parse(freshUrl));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Driver photo fresh URL load failed: $error');
      }
    }

    return null;
  }

  /// Load image bytes via the Storage SDK (works on web; avoids CORS on download URLs).
  Future<Uint8List?> loadBytesFromDownloadUrl(
    String downloadUrl, {
    int maxBytes = _maxPhotoBytes,
  }) async {
    final url = downloadUrl.trim();
    if (url.isEmpty) return null;

    if (_auth.currentUser == null) {
      if (kDebugMode) {
        debugPrint('Storage URL load blocked: user is not signed in.');
      }
      return null;
    }

    try {
      final ref = _storage.refFromURL(url);
      final data = await ref.getData(maxBytes);
      if (data != null && data.isNotEmpty) return data;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Storage getData from URL failed: $error');
      }
    }

    // Path fallback for wallet receipts: .../wallet_recharges/{uid}/{file}
    try {
      final uri = Uri.parse(url);
      final encoded = uri.pathSegments.contains('o')
          ? uri.pathSegments[uri.pathSegments.indexOf('o') + 1]
          : '';
      final path = Uri.decodeComponent(encoded);
      if (path.isNotEmpty) {
        final data = await _storage.ref().child(path).getData(maxBytes);
        if (data != null && data.isNotEmpty) return data;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Storage path fallback failed: $error');
      }
    }

    return null;
  }
}
