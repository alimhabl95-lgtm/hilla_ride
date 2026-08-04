import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hilla_ride/core/models/business_models.dart';
import 'package:uuid/uuid.dart';

class BusinessService {
  BusinessService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1'),
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  // --- Types (config-driven) ---

  Stream<List<BusinessTypeConfig>> watchBusinessTypes() {
    return _firestore.collection('config').doc('businessTypes').snapshots().map(
      (doc) {
        final data = doc.data() ?? {};
        final types = data['types'] as Map<String, dynamic>? ?? {};
        final list = types.entries
            .map(
              (e) => BusinessTypeConfig.fromMap(
                e.key,
                Map<String, dynamic>.from(e.value as Map? ?? {}),
              ),
            )
            .where((t) => t.active)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return list;
      },
    );
  }

  Future<void> seedBusinessTypes() async {
    await _functions.httpsCallable('seedBusinessTypes').call({});
  }

  Future<void> saveBusinessTypes(List<BusinessTypeConfig> types) async {
    await _functions.httpsCallable('saveBusinessTypes').call({
      'types': {for (final t in types) t.id: t.toMap()},
    });
  }

  // --- Businesses ---

  Stream<List<BusinessPartner>> watchBusinesses({
    String? status,
    String? typeId,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> q = _firestore.collection('businesses');
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    if (typeId != null && typeId.isNotEmpty) {
      q = q.where('typeId', isEqualTo: typeId);
    }
    return q.limit(limit).snapshots().map(
          (snap) => snap.docs.map(BusinessPartner.fromDoc).toList()
            ..sort((a, b) => (b.createdAt ?? DateTime(0))
                .compareTo(a.createdAt ?? DateTime(0))),
        );
  }

  Stream<List<BusinessPartner>> watchLiveBusinesses({
    String? typeId,
    String? districtId,
    int limit = 80,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('businesses')
        .where('status', isEqualTo: BusinessStatus.live.value);
    if (typeId != null && typeId.isNotEmpty) {
      q = q.where('typeId', isEqualTo: typeId);
    }
    if (districtId != null && districtId.isNotEmpty) {
      q = q.where('districtId', isEqualTo: districtId);
    }
    return q.limit(limit).snapshots().map(
          (snap) => snap.docs
              .map(BusinessPartner.fromDoc)
              .where((b) => b.isCustomerOrderable)
              .toList(),
        );
  }

  Stream<BusinessPartner?> watchBusiness(String businessId) {
    return _firestore.collection('businesses').doc(businessId).snapshots().map(
          (doc) => doc.exists ? BusinessPartner.fromDoc(doc) : null,
        );
  }

  Future<Map<String, dynamic>> createBusinessPartner({
    required String nameEn,
    required String nameAr,
    required String typeId,
    required String ownerEmail,
    required String ownerPassword,
    required String ownerName,
    String phone = '',
    String provinceId = '',
    String districtId = '',
    String subDistrictId = '',
    double commissionPercent = 15,
  }) async {
    final result = await _functions.httpsCallable('createBusinessPartner').call({
      'nameEn': nameEn,
      'nameAr': nameAr,
      'typeId': typeId,
      'ownerEmail': ownerEmail,
      'ownerPassword': ownerPassword,
      'ownerName': ownerName,
      'phone': phone,
      'provinceId': provinceId,
      'districtId': districtId,
      'subDistrictId': subDistrictId,
      'commissionPercent': commissionPercent,
    });
    return Map<String, dynamic>.from(result.data as Map? ?? {});
  }

  Future<void> setBusinessStatus({
    required String businessId,
    required BusinessStatus status,
    String rejectionReason = '',
  }) async {
    await _functions.httpsCallable('setBusinessStatus').call({
      'businessId': businessId,
      'status': status.value,
      'rejectionReason': rejectionReason,
    });
  }

  Future<void> saveBusinessProfile({
    required String businessId,
    required Map<String, dynamic> data,
  }) async {
    await _functions.httpsCallable('saveBusinessProfile').call({
      'businessId': businessId,
      'data': data,
    });
  }

  Future<void> submitBusinessForReview(String businessId) async {
    await _functions.httpsCallable('submitBusinessForReview').call({
      'businessId': businessId,
    });
  }

  Future<void> deleteBusiness(String businessId) async {
    await _functions.httpsCallable('deleteBusiness').call({
      'businessId': businessId,
    });
  }

  // --- Categories / Products ---

  Stream<List<BusinessCategory>> watchCategories(String businessId) {
    return _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('categories')
        .orderBy('sortOrder')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => BusinessCategory.fromDoc(d, businessId: businessId))
              .toList(),
        );
  }

  Future<String> saveCategory({
    required String businessId,
    String? categoryId,
    required BusinessCategory category,
  }) async {
    final result = await _functions.httpsCallable('saveBusinessCategory').call({
      'businessId': businessId,
      'categoryId': categoryId,
      'data': category.toMap(),
    });
    final data = Map<String, dynamic>.from(result.data as Map? ?? {});
    return data['id']?.toString() ?? categoryId ?? '';
  }

  Future<void> deleteCategory({
    required String businessId,
    required String categoryId,
  }) async {
    await _functions.httpsCallable('deleteBusinessCategory').call({
      'businessId': businessId,
      'categoryId': categoryId,
    });
  }

  Stream<List<BusinessProduct>> watchProducts(
    String businessId, {
    String? categoryId,
    int limit = 200,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('products');
    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.where('categoryId', isEqualTo: categoryId);
    }
    return q.limit(limit).snapshots().map(
          (snap) => snap.docs
              .map((d) => BusinessProduct.fromDoc(d, businessId: businessId))
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        );
  }

  Future<String> saveProduct({
    required String businessId,
    String? productId,
    required BusinessProduct product,
  }) async {
    final result = await _functions.httpsCallable('saveBusinessProduct').call({
      'businessId': businessId,
      'productId': productId,
      'data': product.toMap(),
    });
    final data = Map<String, dynamic>.from(result.data as Map? ?? {});
    return data['id']?.toString() ?? productId ?? '';
  }

  Future<void> deleteProduct({
    required String businessId,
    required String productId,
  }) async {
    await _functions.httpsCallable('deleteBusinessProduct').call({
      'businessId': businessId,
      'productId': productId,
    });
  }

  Future<void> duplicateProduct({
    required String businessId,
    required String productId,
  }) async {
    await _functions.httpsCallable('duplicateBusinessProduct').call({
      'businessId': businessId,
      'productId': productId,
    });
  }

  Future<void> bulkUpdatePrices({
    required String businessId,
    required List<Map<String, dynamic>> updates,
  }) async {
    await _functions.httpsCallable('bulkUpdateBusinessPrices').call({
      'businessId': businessId,
      'updates': updates,
    });
  }

  Future<String> uploadBusinessImage({
    required String businessId,
    required Uint8List bytes,
    required String kind,
  }) async {
    final id = const Uuid().v4();
    final ref = _storage
        .ref()
        .child('businesses')
        .child(businessId)
        .child('$kind-$id.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  // --- Orders ---

  Stream<List<BusinessOrder>> watchOrdersForBusiness(
    String businessId, {
    String? status,
    int limit = 80,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('businessOrders')
        .where('businessId', isEqualTo: businessId);
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    return q
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(BusinessOrder.fromDoc).toList());
  }

  Stream<List<BusinessOrder>> watchAllOrders({int limit = 100}) {
    return _firestore
        .collection('businessOrders')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(BusinessOrder.fromDoc).toList());
  }

  Stream<List<BusinessOrder>> watchCustomerOrders(String customerId) {
    return _firestore
        .collection('businessOrders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((snap) => snap.docs.map(BusinessOrder.fromDoc).toList());
  }

  Stream<List<BusinessOrder>> watchDriverDeliveryOffers(String driverId) {
    return _firestore
        .collection('businessOrders')
        .where('status', whereIn: [
          BusinessOrderStatus.ready.value,
          BusinessOrderStatus.outForDelivery.value,
        ])
        .limit(40)
        .snapshots()
        .map((snap) {
      final all = snap.docs.map(BusinessOrder.fromDoc).toList();
      return all
          .where(
            (o) =>
                o.driverId.isEmpty ||
                o.driverId == driverId ||
                o.status == BusinessOrderStatus.outForDelivery,
          )
          .toList();
    });
  }

  Future<String> placeOrder({
    required String businessId,
    required List<BusinessOrderItem> items,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffLabel,
    String notes = '',
    int deliveryFeeIqd = 2000,
  }) async {
    final result = await _functions.httpsCallable('placeBusinessOrder').call({
      'businessId': businessId,
      'items': items.map((e) => e.toMap()).toList(),
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'dropoffLabel': dropoffLabel,
      'notes': notes,
      'deliveryFeeIqd': deliveryFeeIqd,
    });
    final data = Map<String, dynamic>.from(result.data as Map? ?? {});
    return data['orderId']?.toString() ?? '';
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required BusinessOrderStatus status,
    String? driverId,
  }) async {
    await _functions.httpsCallable('updateBusinessOrderStatus').call({
      'orderId': orderId,
      'status': status.value,
      if (driverId != null) 'driverId': driverId,
    });
  }
}
