import PhotosUI
import SwiftUI
import UIKit

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
    private var isAr: Bool { appState.language == .arabic }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                AppWalletCard(
                    title: isAr ? "الرصيد الحالي" : "Current balance",
                    balance: formatIqd(current.walletBalanceIqd),
                    subtitle: statusText,
                    actionTitle: isAr ? "شحن المحفظة" : "Recharge wallet"
                ) {
                    showRecharge = true
                }

                if isLow || isBlocked {
                    AppBanner(
                        message: isAr
                            ? "رصيد المحفظة منخفض. اشحن عبر سوبر كي لمتابعة استقبال الرحلات."
                            : "Wallet balance is low. Recharge via SuperQi to keep receiving trips.",
                        systemImage: "exclamationmark.triangle.fill",
                        tone: isBlocked ? .danger : .warning
                    )
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(isAr ? "السجل" : "History")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(BrandColors.navy)
                        .padding(.horizontal, AppSpacing.xs)

                    if ledger.isEmpty {
                        AppEmptyState(
                            title: isAr ? "لا توجد عمليات بعد" : "No ledger entries yet",
                            message: isAr
                                ? "ستظهر عمليات الشحن والعمولات هنا"
                                : "Recharges and commissions will appear here",
                            systemImage: "list.bullet.rectangle"
                        )
                        .frame(maxWidth: .infinity)
                        .appCard()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(ledger.enumerated()), id: \.element.id) { index, entry in
                                ledgerRow(entry)
                                if index < ledger.count - 1 {
                                    Divider()
                                        .padding(.leading, AppSpacing.lg)
                                }
                            }
                        }
                        .appCard()
                    }
                }
            }
            .padding(AppSpacing.lg)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationTitle(isAr ? "المحفظة" : "Wallet")
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

    private func ledgerRow(_ entry: WalletLedgerEntry) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: ledgerIcon(for: entry.type))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.amountIqd >= 0 ? BrandColors.success : BrandColors.danger)
                .frame(width: 36, height: 36)
                .background(
                    (entry.amountIqd >= 0 ? BrandColors.success : BrandColors.danger).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(ledgerTypeLabel(entry.type, language: appState.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(BrandColors.muted)
                }
            }

            Spacer(minLength: AppSpacing.sm)

            Text("\(entry.amountIqd >= 0 ? "+" : "")\(formatIqd(entry.amountIqd))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(entry.amountIqd >= 0 ? BrandColors.success : BrandColors.danger)
        }
        .frame(minHeight: 48, alignment: .center)
        .padding(.vertical, AppSpacing.sm)
    }

    private func ledgerIcon(for type: String) -> String {
        switch type.lowercased() {
        case "recharge": return "creditcard.fill"
        case "commission": return "percent"
        case "bonus", "reward": return "gift.fill"
        case "refund": return "arrow.uturn.backward.circle.fill"
        case "penalty": return "exclamationmark.circle.fill"
        default: return "arrow.left.arrow.right"
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
            return isAr
                ? "الحالة: محظور — اشحن المحفظة لاستقبال الرحلات"
                : "Status: Blocked — recharge to receive trips"
        }
        if isLow {
            return isAr ? "الحالة: رصيد منخفض" : "Status: Low balance"
        }
        return isAr ? "الحالة: نشط" : "Status: Active"
    }

    private func formatIqd(_ amount: Int) -> String {
        isAr ? "\(amount) د.ع" : "\(amount) IQD"
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
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                superQiInstructionsCard
                paymentDetailsCard

                if let errorMessage {
                    AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isAr ? "أتممت الدفع — إرسال للمراجعة" : "I completed payment — submit")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSubmitting)
            }
            .padding(AppSpacing.lg)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationTitle(isAr ? "شحن عبر سوبر كي" : "SuperQi recharge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var superQiInstructionsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(config.companySuperQiName)
                .font(.headline.weight(.bold))
                .foregroundStyle(BrandColors.navy)

            Text(
                config.companySuperQiNumber.isEmpty
                    ? (isAr
                        ? "لم يُضبط رقم سوبر كي بعد — تواصل مع الإدارة"
                        : "SuperQi number not set yet — contact admin")
                    : config.companySuperQiNumber
            )
            .font(.title2.weight(.bold))
            .foregroundStyle(BrandColors.tealDark)
            .textSelection(.enabled)

            Text(config.instructions(language: appState.language))
                .font(.footnote)
                .foregroundStyle(BrandColors.muted)

            if !config.managerWhatsappDigits.isEmpty {
                Divider()
                    .padding(.vertical, AppSpacing.xs)

                Text(isAr ? "واتساب استلام الإيصال" : "Send receipt on WhatsApp")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)

                Text(config.managerWhatsappNumber)
                    .font(.headline)
                    .foregroundStyle(BrandColors.tealDark)
                    .textSelection(.enabled)

                Button {
                    openWhatsAppReceipt()
                } label: {
                    Label(
                        isAr ? "فتح واتساب وإرسال الإيصال" : "Open WhatsApp & send receipt",
                        systemImage: "message.fill"
                    )
                }
                .buttonStyle(SecondaryButtonStyle())

                Text(
                    isAr
                        ? "أرفق صورة الإيصال داخل واتساب بعد فتح المحادثة."
                        : "Attach the receipt photo inside WhatsApp after the chat opens."
                )
                .font(.caption)
                .foregroundStyle(BrandColors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var paymentDetailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(isAr ? "تفاصيل الدفع" : "Payment details")
                .font(.headline.weight(.bold))
                .foregroundStyle(BrandColors.navy)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(isAr ? "طريقة الدفع" : "Payment method")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.muted)

                Picker(isAr ? "طريقة الدفع" : "Payment method", selection: $method) {
                    ForEach(config.enabledMethods, id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .background(.white, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                        .stroke(BrandColors.border, lineWidth: 1)
                }
            }

            rechargeField(
                title: isAr ? "المبلغ (د.ع)" : "Amount (IQD)",
                text: $amountText,
                keyboard: .numberPad
            )
            rechargeField(
                title: isAr ? "رقم المرجع (اختياري)" : "Reference (optional)",
                text: $reference
            )
            rechargeField(
                title: isAr ? "ملاحظات (اختياري)" : "Notes (optional)",
                text: $notes
            )

            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: screenshotData == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(screenshotData == nil ? BrandColors.tealDark : BrandColors.success)
                        .frame(width: 44, height: 44)
                        .background(BrandColors.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            screenshotData == nil
                                ? (isAr ? "إرفاق صورة الإيصال" : "Attach receipt screenshot")
                                : (isAr ? "تم اختيار الصورة" : "Screenshot selected")
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.navy)
                        Text(isAr ? "مطلوب للمراجعة" : "Required for review")
                            .font(.caption)
                            .foregroundStyle(BrandColors.muted)
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 48, alignment: .center)
                .padding(AppSpacing.md)
                .background(.white, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                        .stroke(BrandColors.border, lineWidth: 1)
                }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func rechargeField(title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColors.muted)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(AppTextFieldStyle())
        }
    }

    private func openWhatsAppReceipt() {
        let digits = config.managerWhatsappDigits
        guard !digits.isEmpty else {
            errorMessage = isAr
                ? "لم يُضبط رقم واتساب الإدارة بعد"
                : "Manager WhatsApp number is not set yet"
            return
        }
        let amount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let message: String
        if isAr {
            message = """
            شحن محفظة Hello Tuk-Tuk
            السائق: \(driver.name)
            الهاتف: \(driver.phone)
            المبلغ: \(amount.isEmpty ? "—" : amount) د.ع
            الطريقة: \(method)
            المرجع: \(ref.isEmpty ? "—" : ref)
            أرفق صورة إيصال الدفع في هذه المحادثة.
            """
        } else {
            message = """
            Hello Tuk-Tuk wallet recharge
            Driver: \(driver.name)
            Phone: \(driver.phone)
            Amount: \(amount.isEmpty ? "—" : amount) IQD
            Method: \(method)
            Ref: \(ref.isEmpty ? "—" : ref)
            Please attach the payment receipt screenshot here.
            """
        }
        var components = URLComponents(string: "https://wa.me/\(digits)")
        components?.queryItems = [URLQueryItem(name: "text", value: message)]
        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
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
