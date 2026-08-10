import FirebaseFirestore
import Foundation

enum WalletWithdrawalStatus: String, Equatable {
    case pending
    case approved
    case processing
    case completed
    case rejected
    case cancelled

    static func from(_ raw: String?) -> WalletWithdrawalStatus {
        WalletWithdrawalStatus(rawValue: raw ?? "") ?? .pending
    }

    var isOpen: Bool {
        switch self {
        case .pending, .approved, .processing: return true
        case .completed, .rejected, .cancelled: return false
        }
    }
}

struct WalletConfig: Equatable {
    var minBalanceIqd: Int
    var lowBalanceWarningIqd: Int
    var minWithdrawalIqd: Int
    var maxWithdrawalIqd: Int
    var withdrawalsEnabled: Bool
    var companySuperQiNumber: String
    var companySuperQiName: String
    var managerWhatsappNumber: String
    var rechargeInstructionsEn: String
    var rechargeInstructionsAr: String
    var enabledMethods: [String]

    static let `default` = WalletConfig(
        minBalanceIqd: 1,
        lowBalanceWarningIqd: 5000,
        minWithdrawalIqd: 5000,
        maxWithdrawalIqd: 0,
        withdrawalsEnabled: true,
        companySuperQiNumber: "",
        companySuperQiName: "Hello Tuk-Tuk",
        managerWhatsappNumber: "",
        rechargeInstructionsEn:
            "Transfer the amount to the company SuperQi number, then submit your receipt for verification.",
        rechargeInstructionsAr:
            "حوّل المبلغ إلى رقم سوبر كي الخاص بالشركة، ثم أرسل إيصال الدفع للمراجعة.",
        enabledMethods: ["superQi", "cash", "bankTransfer"]
    )

    init(
        minBalanceIqd: Int,
        lowBalanceWarningIqd: Int,
        minWithdrawalIqd: Int = 5000,
        maxWithdrawalIqd: Int = 0,
        withdrawalsEnabled: Bool = true,
        companySuperQiNumber: String,
        companySuperQiName: String,
        managerWhatsappNumber: String,
        rechargeInstructionsEn: String,
        rechargeInstructionsAr: String,
        enabledMethods: [String]
    ) {
        self.minBalanceIqd = minBalanceIqd
        self.lowBalanceWarningIqd = lowBalanceWarningIqd
        self.minWithdrawalIqd = minWithdrawalIqd
        self.maxWithdrawalIqd = maxWithdrawalIqd
        self.withdrawalsEnabled = withdrawalsEnabled
        self.companySuperQiNumber = companySuperQiNumber
        self.companySuperQiName = companySuperQiName
        self.managerWhatsappNumber = managerWhatsappNumber
        self.rechargeInstructionsEn = rechargeInstructionsEn
        self.rechargeInstructionsAr = rechargeInstructionsAr
        self.enabledMethods = enabledMethods
    }

    init(data: [String: Any]?) {
        let source = data ?? [:]
        minBalanceIqd = max((source["minBalanceIqd"] as? NSNumber)?.intValue ?? 1, 1)
        lowBalanceWarningIqd = (source["lowBalanceWarningIqd"] as? NSNumber)?.intValue ?? 5000
        minWithdrawalIqd = (source["minWithdrawalIqd"] as? NSNumber)?.intValue ?? 5000
        maxWithdrawalIqd = (source["maxWithdrawalIqd"] as? NSNumber)?.intValue ?? 0
        withdrawalsEnabled = source["withdrawalsEnabled"] as? Bool ?? true
        companySuperQiNumber = source["companySuperQiNumber"] as? String ?? ""
        companySuperQiName = source["companySuperQiName"] as? String ?? "Hello Tuk-Tuk"
        managerWhatsappNumber = source["managerWhatsappNumber"] as? String ?? ""
        rechargeInstructionsEn = source["rechargeInstructionsEn"] as? String
            ?? WalletConfig.default.rechargeInstructionsEn
        rechargeInstructionsAr = source["rechargeInstructionsAr"] as? String
            ?? WalletConfig.default.rechargeInstructionsAr
        enabledMethods = (source["enabledMethods"] as? [String]) ?? ["superQi", "cash", "bankTransfer"]
    }

    var managerWhatsappDigits: String {
        managerWhatsappNumber.filter(\.isNumber)
    }

    func instructions(language: AppLanguage) -> String {
        language == .arabic ? rechargeInstructionsAr : rechargeInstructionsEn
    }
}

struct WalletLedgerEntry: Identifiable, Equatable {
    let id: String
    let driverId: String
    let type: String
    let amountIqd: Int
    let balanceAfterIqd: Int
    let note: String
    let description: String
    let referenceId: String
    let status: String
    let createdAt: Date?

    /// Prefers `description`, falls back to `note`.
    var displayDescription: String {
        description.isEmpty ? note : description
    }

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        driverId = data["driverId"] as? String ?? ""
        type = data["type"] as? String ?? "adjustment"
        amountIqd = (data["amountIqd"] as? NSNumber)?.intValue ?? 0
        balanceAfterIqd = (data["balanceAfterIqd"] as? NSNumber)?.intValue ?? 0
        note = data["note"] as? String ?? ""
        description = data["description"] as? String ?? ""
        status = data["status"] as? String ?? "posted"
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()

        let rideId = data["rideId"] as? String ?? ""
        let rechargeRequestId = data["rechargeRequestId"] as? String ?? ""
        let withdrawalRequestId = data["withdrawalRequestId"] as? String ?? ""
        let rewardGrantId = data["rewardGrantId"] as? String ?? ""
        let explicitRef = data["referenceId"] as? String ?? ""
        if !explicitRef.isEmpty {
            referenceId = explicitRef
        } else if !withdrawalRequestId.isEmpty {
            referenceId = withdrawalRequestId
        } else if !rechargeRequestId.isEmpty {
            referenceId = rechargeRequestId
        } else if !rideId.isEmpty {
            referenceId = rideId
        } else {
            referenceId = rewardGrantId
        }
    }
}

struct WalletWithdrawalRequest: Identifiable, Equatable {
    let id: String
    let driverId: String
    let amountIqd: Int
    let status: WalletWithdrawalStatus
    let cardholderName: String
    let cardLast4: String
    let cardBrand: String
    let referenceId: String
    let rejectionReason: String
    let createdAt: Date?

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        driverId = data["driverId"] as? String ?? ""
        amountIqd = (data["amountIqd"] as? NSNumber)?.intValue ?? 0
        status = WalletWithdrawalStatus.from(data["status"] as? String)
        cardholderName = data["cardholderName"] as? String ?? ""
        cardLast4 = data["cardLast4"] as? String ?? ""
        cardBrand = data["cardBrand"] as? String ?? "mastercard"
        referenceId = data["referenceId"] as? String ?? ""
        rejectionReason = data["rejectionReason"] as? String ?? ""
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}
