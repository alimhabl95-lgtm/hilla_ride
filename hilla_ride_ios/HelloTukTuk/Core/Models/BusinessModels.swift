import FirebaseFirestore
import Foundation

struct BusinessTypeConfig: Identifiable, Equatable {
    let id: String
    let nameEn: String
    let nameAr: String
    let icon: String
    let sortOrder: Int
    let active: Bool

    func name(language: AppLanguage) -> String {
        language == .arabic ? nameAr : nameEn
    }

    init?(id: String, data: [String: Any]) {
        self.id = id
        nameEn = data["nameEn"] as? String ?? id
        nameAr = data["nameAr"] as? String ?? id
        icon = data["icon"] as? String ?? "store"
        sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0
        active = data["active"] as? Bool ?? true
    }
}

enum BusinessOrderStatus: String, Equatable {
    case pending
    case accepted
    case preparing
    case ready
    case outForDelivery
    case delivered
    case cancelled
    case rejected

    static func from(_ raw: String?) -> BusinessOrderStatus {
        BusinessOrderStatus(rawValue: raw ?? "") ?? .pending
    }
}

struct BusinessCategory: Identifiable, Equatable {
    let id: String
    let businessId: String
    let nameEn: String
    let nameAr: String
    let sortOrder: Int
    let active: Bool

    func name(language: AppLanguage) -> String {
        language == .arabic ? (nameAr.isEmpty ? nameEn : nameAr) : nameEn
    }

    init?(documentID: String, businessId: String, data: [String: Any]) {
        id = documentID
        self.businessId = businessId
        nameEn = data["nameEn"] as? String ?? ""
        nameAr = data["nameAr"] as? String ?? ""
        sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0
        active = data["active"] as? Bool ?? true
    }
}

struct BusinessPartner: Identifiable, Equatable {
    let id: String
    let nameEn: String
    let nameAr: String
    let typeId: String
    let status: String
    let descriptionEn: String
    let descriptionAr: String
    let logoUrl: String
    let coverUrl: String
    let phone: String
    let address: String
    let latitude: Double
    let longitude: Double
    let rating: Double
    let ratingCount: Int
    let temporarilyClosed: Bool

    var isCustomerOrderable: Bool {
        status == "live" && !temporarilyClosed
    }

    func name(language: AppLanguage) -> String {
        language == .arabic ? (nameAr.isEmpty ? nameEn : nameAr) : nameEn
    }

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        nameEn = data["nameEn"] as? String ?? ""
        nameAr = data["nameAr"] as? String ?? ""
        typeId = data["typeId"] as? String ?? "store"
        status = data["status"] as? String ?? "draft"
        descriptionEn = data["descriptionEn"] as? String ?? ""
        descriptionAr = data["descriptionAr"] as? String ?? ""
        logoUrl = data["logoUrl"] as? String ?? ""
        coverUrl = data["coverUrl"] as? String ?? ""
        phone = data["phone"] as? String ?? ""
        address = data["address"] as? String ?? ""
        latitude = (data["latitude"] as? NSNumber)?.doubleValue ?? 0
        longitude = (data["longitude"] as? NSNumber)?.doubleValue ?? 0
        rating = (data["rating"] as? NSNumber)?.doubleValue ?? 0
        ratingCount = (data["ratingCount"] as? NSNumber)?.intValue ?? 0
        temporarilyClosed = data["temporarilyClosed"] as? Bool ?? false
    }
}

struct BusinessProduct: Identifiable, Equatable {
    let id: String
    let businessId: String
    let categoryId: String
    let nameEn: String
    let nameAr: String
    let descriptionEn: String
    let descriptionAr: String
    let imageUrl: String
    let priceIqd: Int
    let discountPercent: Double
    let available: Bool
    let prepMinutes: Int
    let sortOrder: Int

    var effectivePriceIqd: Int {
        guard discountPercent > 0 else { return priceIqd }
        return Int((Double(priceIqd) * (100 - discountPercent) / 100).rounded())
    }

    func name(language: AppLanguage) -> String {
        language == .arabic ? (nameAr.isEmpty ? nameEn : nameAr) : nameEn
    }

    init?(documentID: String, businessId: String, data: [String: Any]) {
        id = documentID
        self.businessId = businessId
        categoryId = data["categoryId"] as? String ?? ""
        nameEn = data["nameEn"] as? String ?? ""
        nameAr = data["nameAr"] as? String ?? ""
        descriptionEn = data["descriptionEn"] as? String ?? ""
        descriptionAr = data["descriptionAr"] as? String ?? ""
        imageUrl = data["imageUrl"] as? String ?? ""
        priceIqd = (data["priceIqd"] as? NSNumber)?.intValue ?? 0
        discountPercent = (data["discountPercent"] as? NSNumber)?.doubleValue ?? 0
        available = data["available"] as? Bool ?? true
        prepMinutes = (data["prepMinutes"] as? NSNumber)?.intValue ?? 15
        sortOrder = (data["sortOrder"] as? NSNumber)?.intValue ?? 0
    }
}

struct BusinessOrderItem: Equatable {
    let productId: String
    let nameEn: String
    let nameAr: String
    let unitPriceIqd: Int
    let quantity: Int

    func toMap() -> [String: Any] {
        [
            "productId": productId,
            "nameEn": nameEn,
            "nameAr": nameAr,
            "unitPriceIqd": unitPriceIqd,
            "quantity": quantity
        ]
    }

    init(productId: String, nameEn: String, nameAr: String, unitPriceIqd: Int, quantity: Int) {
        self.productId = productId
        self.nameEn = nameEn
        self.nameAr = nameAr
        self.unitPriceIqd = unitPriceIqd
        self.quantity = quantity
    }

    init?(data: [String: Any]) {
        productId = data["productId"] as? String ?? ""
        nameEn = data["nameEn"] as? String ?? ""
        nameAr = data["nameAr"] as? String ?? ""
        unitPriceIqd = (data["unitPriceIqd"] as? NSNumber)?.intValue ?? 0
        quantity = (data["quantity"] as? NSNumber)?.intValue ?? 1
    }
}

struct BusinessOrder: Identifiable, Equatable {
    let id: String
    let businessId: String
    let businessName: String
    let customerId: String
    let driverId: String
    let status: BusinessOrderStatus
    let deliveryFeeIqd: Int
    let totalIqd: Int
    let dropoffLabel: String

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        businessId = data["businessId"] as? String ?? ""
        businessName = data["businessName"] as? String ?? ""
        customerId = data["customerId"] as? String ?? ""
        driverId = data["driverId"] as? String ?? ""
        status = BusinessOrderStatus.from(data["status"] as? String)
        deliveryFeeIqd = (data["deliveryFeeIqd"] as? NSNumber)?.intValue ?? 0
        totalIqd = (data["totalIqd"] as? NSNumber)?.intValue ?? 0
        dropoffLabel = data["dropoffLabel"] as? String ?? ""
    }
}
