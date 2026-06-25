import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hilla_ride/core/models/announcement.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementService {
  AnnouncementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _readIdsController = StreamController<Set<String>>.broadcast();
  static const _readIdsKey = 'read_announcement_ids';

  Stream<List<Announcement>> watchAnnouncements(String audience) {
    return _firestore
        .collection('announcements')
        .where('audience', isEqualTo: audience)
        .limit(40)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => Announcement.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }

  Stream<Set<String>> watchReadIds() async* {
    yield await getReadIds();
    yield* _readIdsController.stream;
  }

  Future<Set<String>> getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_readIdsKey) ?? const [];
    return list.toSet();
  }

  Future<void> _publishReadIds() async {
    if (_readIdsController.isClosed) return;
    _readIdsController.add(await getReadIds());
  }

  Future<void> markRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final read = await getReadIds();
    if (read.contains(id)) return;
    read.add(id);
    await prefs.setStringList(_readIdsKey, read.toList());
    await _publishReadIds();
  }

  Future<void> markAllRead(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final read = await getReadIds();
    read.addAll(ids);
    await prefs.setStringList(_readIdsKey, read.toList());
    await _publishReadIds();
  }

  int unreadCount(List<Announcement> announcements, Set<String> readIds) {
    return announcements.where((item) => !readIds.contains(item.id)).length;
  }
}
