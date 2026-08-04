import FirebaseFirestore
import Foundation

struct WalletConfig: Equatable {
    var minBalanceIqd: Int
    var lowBalanceWarningIqd: Int
    var companySuperQiNumber: String
    var companySuperQiName: String
    var managerWhatsappNumber: String
    var rechargeInstructionsEn: String
    var rechargeInstructionsAr: String
    var enabledMethods: [String]

    static let `default` = WalletConfig(
        minBalanceIqd: 1,
        lowBalanceWarningIqd: 5000,
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
        companySuperQiNumber: String,
        companySuperQiName: String,
        managerWhatsappNumber: String,
        rechargeInstructionsEn: String,
        rechargeInstructionsAr: String,
        enabledMethods: [String]
    ) {
        self.minBalanceIqd = minBalanceIqd
        self.lowBalanceWarningIqd = lowBalanceWarningIqd
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
    let createdAt: Date?

    init?(documentID: String, data: [String: Any]) {
        id = documentID
        driverId = data["driverId"] as? String ?? ""
        type = data["type"] as? String ?? "adjustment"
        amountIqd = (data["amountIqd"] as? NSNumber)?.intValue ?? 0
        balanceAfterIqd = (data["balanceAfterIqd"] as? NSNumber)?.intValue ?? 0
        note = data["note"] as? String ?? ""
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
    }
}
