import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/manager_permissions.dart';

class AssistantService {
  AssistantService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Stream<List<AppUser>> watchAssistants() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: UserRole.assistant.value)
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

  /// Self-registration: creates the Firebase Auth login with the client SDK
  /// (no Cloud Function needed) and writes a pending assistant profile that a
  /// manager must approve before the account can access the dashboard.
  Future<String> registerAssistant({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'name': name.trim(),
      'phone': '',
      'email': email.trim().toLowerCase(),
      'role': UserRole.assistant.value,
      'age': 18,
      'permissions': <String>[],
      'isBlocked': true,
      'approvalStatus': 'pending',
      'cancelledRidesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return uid;
  }

  /// Approves a pending assistant and grants the selected permissions.
  Future<void> approveAssistant({
    required String assistantId,
    required List<String> permissions,
    String roleTemplate = '',
  }) async {
    await _firestore.collection('users').doc(assistantId).update({
      'permissions': sanitizePermissions(permissions),
      'approvalStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'isBlocked': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (roleTemplate.isNotEmpty) 'roleTemplate': roleTemplate,
    });
  }

  Future<String> createAssistant({
    required String name,
    required String email,
    required String password,
    required List<String> permissions,
    String roleTemplate = '',
  }) async {
    final callable = _functions.httpsCallable('createAssistant');
    final result = await callable.call<Map<String, dynamic>>({
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'permissions': permissions,
      if (roleTemplate.isNotEmpty) 'roleTemplate': roleTemplate,
    });
    return result.data['uid'] as String? ?? '';
  }

  Future<void> updateAssistantPermissions({
    required String assistantId,
    required List<String> permissions,
    String roleTemplate = '',
  }) async {
    await _firestore.collection('users').doc(assistantId).update({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
      if (roleTemplate.isNotEmpty) 'roleTemplate': roleTemplate,
    });
  }

  Future<void> deactivateAssistant(String assistantId) async {
    await setAssistantEnabled(assistantId: assistantId, enabled: false);
  }

  /// Enables or disables an assistant account. A disabled assistant is blocked
  /// from signing in to the dashboard until re-enabled.
  Future<void> setAssistantEnabled({
    required String assistantId,
    required bool enabled,
  }) async {
    final data = <String, dynamic>{
      'isBlocked': !enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (!enabled) {
      data['blockedAt'] = FieldValue.serverTimestamp();
    }
    await _firestore.collection('users').doc(assistantId).update(data);
  }

  List<String> sanitizePermissions(List<String> permissions) {
    return permissions.where(AdminPermissions.all.contains).toSet().toList();
  }
}
