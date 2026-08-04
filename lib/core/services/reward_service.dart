import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:hilla_ride/core/models/reward_models.dart';

class RewardService {
  RewardService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<RewardCampaign>> watchCampaigns({bool includeDeleted = false}) {
    return _firestore
        .collection('rewardCampaigns')
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snap) {
      final items = snap.docs.map(RewardCampaign.fromDoc).toList();
      if (includeDeleted) return items;
      return items
          .where((c) => c.status != RewardCampaignStatus.deleted)
          .toList();
    });
  }

  Stream<List<RewardCampaign>> watchActiveCampaigns() {
    return _firestore
        .collection('rewardCampaigns')
        .where('status', isEqualTo: RewardCampaignStatus.active.value)
        .snapshots()
        .map((snap) => snap.docs.map(RewardCampaign.fromDoc).toList());
  }

  Stream<List<RewardGrant>> watchGrantsForCampaign(String campaignId) {
    return _firestore
        .collection('rewardGrants')
        .where('campaignId', isEqualTo: campaignId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(RewardGrant.fromDoc).toList());
  }

  Stream<List<RewardGrant>> watchDriverGrants(String driverId) {
    return _firestore
        .collection('rewardGrants')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(RewardGrant.fromDoc).toList());
  }

  Stream<List<RewardProgress>> watchDriverProgress(String driverId) {
    return _firestore
        .collection('rewardProgress')
        .where('driverId', isEqualTo: driverId)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(RewardProgress.fromDoc).toList());
  }

  Stream<List<RewardAuditLog>> watchAuditLogs({String? campaignId}) {
    Query<Map<String, dynamic>> q = _firestore.collection('rewardAuditLogs');
    if (campaignId != null && campaignId.isNotEmpty) {
      q = q.where('campaignId', isEqualTo: campaignId);
    }
    return q
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((snap) => snap.docs.map(RewardAuditLog.fromDoc).toList());
  }

  Future<String> saveCampaign(RewardCampaign campaign, {String? id}) async {
    final callable = _functions.httpsCallable('saveRewardCampaign');
    final result = await callable.call(campaign.toCallablePayload(id: id));
    final data = Map<String, dynamic>.from(result.data as Map? ?? {});
    return data['id']?.toString() ?? id ?? '';
  }

  Future<void> setCampaignStatus({
    required String id,
    required RewardCampaignStatus status,
  }) async {
    final callable = _functions.httpsCallable('setRewardCampaignStatus');
    await callable.call({'id': id, 'status': status.value});
  }

  Future<void> deleteCampaign(String id) async {
    final callable = _functions.httpsCallable('deleteRewardCampaign');
    await callable.call({'id': id});
  }

  Future<Map<String, dynamic>> evaluateDriver(String driverId) async {
    final callable = _functions.httpsCallable('evaluateDriverRewards');
    final result = await callable.call({'driverId': driverId});
    return Map<String, dynamic>.from(result.data as Map? ?? {});
  }
}
