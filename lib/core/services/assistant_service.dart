import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hilla_ride/core/models/app_models.dart';
import 'package:hilla_ride/core/models/manager_permissions.dart';

class AssistantService {
  AssistantService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
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

  Future<String> createAssistant({
    required String name,
    required String email,
    required String password,
    required List<String> permissions,
  }) async {
    final callable = _functions.httpsCallable('createAssistant');
    final result = await callable.call<Map<String, dynamic>>({
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'permissions': permissions,
    });
    return result.data['uid'] as String? ?? '';
  }

  Future<void> updateAssistantPermissions({
    required String assistantId,
    required List<String> permissions,
  }) async {
    await _firestore.collection('users').doc(assistantId).update({
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deactivateAssistant(String assistantId) async {
    await _firestore.collection('users').doc(assistantId).update({
      'isBlocked': true,
      'blockedAt': FieldValue.serverTimestamp(),
    });
  }

  List<String> sanitizePermissions(List<String> permissions) {
    return permissions.where(AdminPermissions.all.contains).toSet().toList();
  }
}
