import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SessionService {
  SessionService({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  String _prefsKey(String uid) => 'active_session_$uid';

  Future<String?> _readLocalSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey(uid));
  }

  Future<void> _writeLocalSession(String uid, String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(uid), sessionId);
  }

  Future<void> _clearLocalSession(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(uid));
  }

  Future<String?> _readRemoteSession(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final value = doc.data()?['activeSessionId'];
    if (value is! String || value.isEmpty) return null;
    return value;
  }

  Future<void> assertSingleDeviceLogin(String uid) async {
    final remote = await _readRemoteSession(uid);
    if (remote == null) return;

    final local = await _readLocalSession(uid);
    if (local == remote) return;

    throw FirebaseAuthException(
      code: 'session-active',
      message: 'This account is already open on another phone.',
    );
  }

  Future<void> claimSession(String uid) async {
    final sessionId = _uuid.v4();
    await _writeLocalSession(uid, sessionId);
    await _firestore.collection('users').doc(uid).set(
      {
        'activeSessionId': sessionId,
        'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<bool> validateLocalSession(String uid) async {
    final remote = await _readRemoteSession(uid);
    if (remote == null) {
      await claimSession(uid);
      return true;
    }

    final local = await _readLocalSession(uid);
    return local != null && local == remote;
  }

  Future<bool> isSessionValid(String uid) async {
    final remote = await _readRemoteSession(uid);
    if (remote == null) return true;
    final local = await _readLocalSession(uid);
    return local != null && local == remote;
  }

  Future<void> clearSession(String uid) async {
    final local = await _readLocalSession(uid);
    final remote = await _readRemoteSession(uid);
    if (local != null && local == remote) {
      await _firestore.collection('users').doc(uid).update({
        'activeSessionId': FieldValue.delete(),
        'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
    await _clearLocalSession(uid);
  }

  Stream<String?> watchRemoteSession(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final value = doc.data()?['activeSessionId'];
      if (value is! String || value.isEmpty) return null;
      return value;
    });
  }
}
