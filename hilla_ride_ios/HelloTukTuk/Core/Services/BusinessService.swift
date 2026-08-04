import FirebaseFirestore
import FirebaseFunctions
import Foundation

/// Live marketplace data — businesses, products, and orders from Firestore/Functions.
final class BusinessService {
    private let firestore = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    func watchBusinessTypes() -> AsyncStream<[BusinessTypeConfig]> {
        AsyncStream { continuation in
            let listener = firestore.collection("config").document("businessTypes")
                .addSnapshotListener { snapshot, _ in
                    let typesMap = snapshot?.data()?["types"] as? [String: Any] ?? [:]
                    let types = typesMap.compactMap { key, value -> BusinessTypeConfig? in
                        guard let data = value as? [String: Any] else { return nil }
                        return BusinessTypeConfig(id: key, data: data)
                    }
                    .filter(\.active)
                    .sorted { $0.sortOrder < $1.sortOrder }
                    continuation.yield(types)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchLiveBusinesses(typeId: String? = nil, limit: Int = 80) -> AsyncStream<[BusinessPartner]> {
        AsyncStream { continuation in
            var query: Query = firestore.collection("businesses")
                .whereField("status", isEqualTo: "live")
            if let typeId, !typeId.isEmpty {
                query = query.whereField("typeId", isEqualTo: typeId)
            }
            let listener = query.limit(to: limit).addSnapshotListener { snapshot, _ in
                let items = (snapshot?.documents.compactMap {
                    BusinessPartner(documentID: $0.documentID, data: $0.data())
                } ?? []).filter(\.isCustomerOrderable)
                continuation.yield(items)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchBusiness(businessId: String) -> AsyncStream<BusinessPartner?> {
        AsyncStream { continuation in
            let listener = firestore.collection("businesses").document(businessId)
                .addSnapshotListener { snapshot, _ in
                    guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                        continuation.yield(nil)
                        return
                    }
                    continuation.yield(BusinessPartner(documentID: snapshot.documentID, data: data))
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchCategories(businessId: String) -> AsyncStream<[BusinessCategory]> {
        AsyncStream { continuation in
            let listener = firestore.collection("businesses").document(businessId)
                .collection("categories")
                .order(by: "sortOrder")
                .addSnapshotListener { snapshot, _ in
                    let items = snapshot?.documents.compactMap {
                        BusinessCategory(
                            documentID: $0.documentID,
                            businessId: businessId,
                            data: $0.data()
                        )
                    } ?? []
                    continuation.yield(items)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchProducts(businessId: String, limit: Int = 200) -> AsyncStream<[BusinessProduct]> {
        AsyncStream { continuation in
            let listener = firestore.collection("businesses").document(businessId)
                .collection("products")
                .limit(to: limit)
                .addSnapshotListener { snapshot, _ in
                    let items = (snapshot?.documents.compactMap {
                        BusinessProduct(
                            documentID: $0.documentID,
                            businessId: businessId,
                            data: $0.data()
                        )
                    } ?? []).sorted { $0.sortOrder < $1.sortOrder }
                    continuation.yield(items)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchDriverDeliveryOffers(driverId: String) -> AsyncStream<[BusinessOrder]> {
        AsyncStream { continuation in
            let listener = firestore.collection("businessOrders")
                .whereField("status", in: ["ready", "outForDelivery"])
                .limit(to: 40)
                .addSnapshotListener { snapshot, _ in
                    let all = snapshot?.documents.compactMap {
                        BusinessOrder(documentID: $0.documentID, data: $0.data())
                    } ?? []
                    let filtered = all.filter { order in
                        order.driverId.isEmpty
                            || order.driverId == driverId
                            || order.status == .outForDelivery
                    }
                    continuation.yield(filtered)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func placeOrder(
        businessId: String,
        items: [BusinessOrderItem],
        dropoffLat: Double,
        dropoffLng: Double,
        dropoffLabel: String,
        notes: String = "",
        deliveryFeeIqd: Int = 2000
    ) async throws -> String {
        let result = try await functions.httpsCallable("placeBusinessOrder").call([
            "businessId": businessId,
            "items": items.map { $0.toMap() },
            "dropoffLat": dropoffLat,
            "dropoffLng": dropoffLng,
            "dropoffLabel": dropoffLabel,
            "notes": notes,
            "deliveryFeeIqd": deliveryFeeIqd
        ])
        let data = result.data as? [String: Any] ?? [:]
        return data["orderId"] as? String ?? ""
    }

    func updateOrderStatus(
        orderId: String,
        status: BusinessOrderStatus,
        driverId: String? = nil
    ) async throws {
        var payload: [String: Any] = [
            "orderId": orderId,
            "status": status.rawValue
        ]
        if let driverId {
            payload["driverId"] = driverId
        }
        _ = try await functions.httpsCallable("updateBusinessOrderStatus").call(payload)
    }

    func fetchBusiness(businessId: String) async throws -> BusinessPartner? {
        let snap = try await firestore.collection("businesses").document(businessId).getDocument()
        guard snap.exists, let data = snap.data() else { return nil }
        return BusinessPartner(documentID: snap.documentID, data: data)
    }
}
