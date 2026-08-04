import PhotosUI
import SwiftUI

struct DriverWalletView: View {
    @EnvironmentObject private var appState: AppState
    let driver: DriverProfile

    @State private var liveDriver: DriverProfile?
    @State private var config = WalletConfig.default
    @State private var ledger: [WalletLedgerEntry] = []
    @State private var showRecharge = false
    @State private var driverTask: Task<Void, Never>?
    @State private var configTask: Task<Void, Never>?
    @State private var ledgerTask: Task<Void, Never>?

    private var current: DriverProfile { liveDriver ?? driver }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.language == .arabic ? "الرصيد الحالي" : "Current balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatIqd(current.walletBalanceIqd))
                        .font(.largeTitle.bold())
                        .foregroundStyle(BrandColors.tealDark)
                    Text(statusText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
                .padding(.vertical, 4)

                if isLow || isBlocked {
                    Text(
                        appState.language == .arabic
                            ? "رصيد المحفظة منخفض. اشحن عبر سوبر كي لمتابعة استقبال الرحلات."
                            : "Wallet balance is low. Recharge via SuperQi to keep receiving trips."
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                }

                Button {
                    showRecharge = true
                } label: {
                    Label(
                        appState.language == .arabic ? "شحن المحفظة" : "Recharge wallet",
                        systemImage: "creditcard"
                    )
                }
            }

            Section(appState.language == .arabic ? "السجل" : "History") {
                if ledger.isEmpty {
                    Text(appState.language == .arabic ? "لا توجد عمليات بعد" : "No ledger entries yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ledger) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ledgerTypeLabel(entry.type, language: appState.language))
                                    .font(.subheadline.weight(.semibold))
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(entry.amountIqd >= 0 ? "+" : "")\(formatIqd(entry.amountIqd))")
                                .foregroundStyle(entry.amountIqd >= 0 ? .green : .red)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle(appState.language == .arabic ? "المحفظة" : "Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRecharge) {
            DriverWalletRechargeView(driver: current, config: config)
        }
        .onAppear { startWatching() }
        .onDisappear {
            driverTask?.cancel()
            configTask?.cancel()
            ledgerTask?.cancel()
        }
    }

    private var isBlocked: Bool {
        current.walletStatus == "blocked" || current.walletBalanceIqd < config.minBalanceIqd
    }

    private var isLow: Bool {
        current.walletBalanceIqd <= config.lowBalanceWarningIqd
    }

    private var statusText: String {
        if isBlocked {
            return appState.language == .arabic
                ? "الحالة: محظور — اشحن المحفظة لاستقبال الرحلات"
                : "Status: Blocked — recharge to receive trips"
        }
        if isLow {
            return appState.language == .arabic ? "الحالة: رصيد منخفض" : "Status: Low balance"
        }
        return appState.language == .arabic ? "الحالة: نشط" : "Status: Active"
    }

    private var statusColor: Color {
        if isBlocked { return .red }
        if isLow { return .orange }
        return BrandColors.tealDark
    }

    private func formatIqd(_ amount: Int) -> String {
        appState.language == .arabic ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func ledgerTypeLabel(_ type: String, language: AppLanguage) -> String {
        let ar = language == .arabic
        switch type.lowercased() {
        case "recharge": return ar ? "شحن" : "Recharge"
        case "commission": return ar ? "عمولة" : "Commission"
        case "adjustment": return ar ? "تعديل" : "Adjustment"
        case "refund": return ar ? "استرداد" : "Refund"
        case "bonus": return ar ? "مكافأة" : "Bonus"
        case "penalty": return ar ? "غرامة" : "Penalty"
        case "reward": return ar ? "حافز / مكافأة" : "Reward"
        default: return type.capitalized
        }
    }

    private func startWatching() {
        let uid = driver.uid
        driverTask = Task {
            for await profile in DriverRepository().watchDriver(uid: uid) {
                guard !Task.isCancelled else { break }
                await MainActor.run { liveDriver = profile }
            }
        }
        configTask = Task {
            for await value in WalletService().watchConfig() {
                guard !Task.isCancelled else { break }
                await MainActor.run { config = value }
            }
        }
        ledgerTask = Task {
            for await entries in WalletService().watchLedger(driverId: uid) {
                guard !Task.isCancelled else { break }
                await MainActor.run { ledger = entries }
            }
        }
    }
}

struct DriverWalletRechargeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let driver: DriverProfile
    let config: WalletConfig

    @State private var amountText = ""
    @State private var reference = ""
    @State private var notes = ""
    @State private var method = "superQi"
    @State private var selectedItem: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isAr: Bool { appState.language == .arabic }

    var body: some View {
        Form {
            Section {
                Text(config.companySuperQiName)
                    .font(.headline)
                Text(
                    config.companySuperQiNumber.isEmpty
                        ? (isAr
                            ? "لم يُضبط رقم سوبر كي بعد — تواصل مع الإدارة"
                            : "SuperQi number not set yet — contact admin")
                        : config.companySuperQiNumber
                )
                .font(.title2.bold())
                .foregroundStyle(BrandColors.tealDark)
                .textSelection(.enabled)
                Text(config.instructions(language: appState.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(isAr ? "طريقة الدفع" : "Payment method", selection: $method) {
                    ForEach(config.enabledMethods, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                TextField(isAr ? "المبلغ (د.ع)" : "Amount (IQD)", text: $amountText)
                    .keyboardType(.numberPad)
                TextField(isAr ? "رقم المرجع (اختياري)" : "Reference (optional)", text: $reference)
                TextField(isAr ? "ملاحظات (اختياري)" : "Notes (optional)", text: $notes)
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label(
                        screenshotData == nil
                            ? (isAr ? "إرفاق صورة الإيصال" : "Attach receipt screenshot")
                            : (isAr ? "تم اختيار الصورة" : "Screenshot selected"),
                        systemImage: "photo"
                    )
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        guard let newItem else { return }
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run { screenshotData = data }
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text(isAr ? "أتممت الدفع — إرسال للمراجعة" : "I completed payment — submit")
                    }
                }
                .disabled(isSubmitting)
            }
        }
        .navigationTitle(isAr ? "شحن عبر سوبر كي" : "SuperQi recharge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() async {
        errorMessage = nil
        let amount = Int(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard amount >= 1000 else {
            errorMessage = isAr ? "الحد الأدنى 1000 د.ع" : "Minimum is 1000 IQD"
            return
        }
        guard let screenshotData else {
            errorMessage = isAr ? "أرفق صورة إيصال الدفع" : "Attach a payment screenshot"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let service = WalletService()
            let url = try await service.uploadRechargeScreenshot(
                driverId: driver.uid,
                data: screenshotData
            )
            try await service.submitRechargeRequest(
                amountIqd: amount,
                method: method,
                screenshotUrl: url,
                referenceNumber: reference,
                notes: notes
            )
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
