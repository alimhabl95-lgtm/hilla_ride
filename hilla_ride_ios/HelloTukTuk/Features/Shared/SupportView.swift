import SwiftUI

private struct FaqItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct SupportView: View {
    @EnvironmentObject private var appState: AppState

    @State private var contact = SupportContactInfo.defaults
    @State private var message = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var priorMessages: [SupportMessage] = []
    @State private var messagesTask: Task<Void, Never>?
    @State private var reportSheet: ReportSheetConfig?
    @State private var reportSent = false
    @State private var reportError = false

    private var isArabic: Bool { appState.language == .arabic }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.helpSupportTitle, language: appState.language))
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrandColors.navy)

                faqSection
                contactSection
                reportSection
                chatSection
                legalSection
            }
            .padding(24)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            contact = await SupportService().getContactInfo()
        }
        .onAppear { startWatchingMessages() }
        .onDisappear { messagesTask?.cancel() }
        .sheet(item: $reportSheet) { config in
            ReportComplaintSheet(
                config: config,
                language: appState.language,
                user: appState.currentUser,
                onSubmit: { targetName, rideId, details in
                    await submitReport(
                        config: config,
                        targetName: targetName,
                        rideId: rideId,
                        details: details
                    )
                }
            )
        }
        .alert(
            reportSent
                ? L10n.string(.reportSubmittedTitle, language: appState.language)
                : L10n.string(.reportFailedTitle, language: appState.language),
            isPresented: Binding(
                get: { reportSent || reportError },
                set: { if !$0 { reportSent = false; reportError = false } }
            )
        ) {
            Button(L10n.string(.ok, language: appState.language), role: .cancel) {}
        } message: {
            Text(
                reportSent
                    ? L10n.string(.reportSubmittedMessage, language: appState.language)
                    : L10n.string(.reportFailedMessage, language: appState.language)
            )
        }
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(.faqTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)
            ForEach(faqItems) { item in
                DisclosureGroup(item.question) {
                    Text(item.answer)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .tint(BrandColors.tealDark)
            }
        }
        .appCard()
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(.contactUsTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)
            contactButton(
                icon: "phone.fill",
                value: contact.phone,
                url: "tel:\(contact.phone)"
            )
            contactButton(
                icon: "message.fill",
                value: contact.whatsapp,
                url: "https://wa.me/\(contact.whatsapp.filter { $0.isNumber })"
            )
            contactButton(
                icon: "envelope.fill",
                value: contact.email,
                url: "mailto:\(contact.email)"
            )
        }
        .appCard()
    }

    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(.reportProblemTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)

            reportButton(
                title: L10n.string(.reportGeneral, language: appState.language),
                icon: "exclamationmark.triangle"
            ) {
                reportSheet = ReportSheetConfig(
                    category: "general",
                    subject: isArabic ? "بلاغ عام" : "General report",
                    targetRole: "",
                    targetLabel: ""
                )
            }

            if appState.currentUser?.role == .customer {
                reportButton(
                    title: L10n.string(.reportDriver, language: appState.language),
                    icon: "car.fill"
                ) {
                    reportSheet = ReportSheetConfig(
                        category: "driver",
                        subject: isArabic ? "بلاغ ضد سائق" : "Report driver",
                        targetRole: "driver",
                        targetLabel: isArabic ? "اسم أو رقم السائق" : "Driver name or ID"
                    )
                }
                reportButton(
                    title: L10n.string(.reportBusiness, language: appState.language),
                    icon: "storefront.fill"
                ) {
                    reportSheet = ReportSheetConfig(
                        category: "business",
                        subject: isArabic ? "بلاغ ضد متجر" : "Report business",
                        targetRole: "businessOwner",
                        targetLabel: isArabic ? "اسم المتجر" : "Business name"
                    )
                }
            }

            if appState.currentUser?.role == .driver {
                reportButton(
                    title: L10n.string(.reportCustomer, language: appState.language),
                    icon: "person.fill"
                ) {
                    reportSheet = ReportSheetConfig(
                        category: "customer",
                        subject: isArabic ? "بلاغ ضد راكب" : "Report customer",
                        targetRole: "customer",
                        targetLabel: isArabic ? "اسم أو رقم الراكب" : "Customer name or ID"
                    )
                }
            }
        }
        .appCard()
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(.supportChatTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)

            if !priorMessages.isEmpty {
                Text(L10n.string(.supportPreviousMessages, language: appState.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                ForEach(priorMessages) { item in
                    VStack(alignment: item.isFromManager ? .leading : .trailing, spacing: 4) {
                        Text(item.message)
                            .padding(10)
                            .background(item.isFromManager ? BrandColors.border.opacity(0.5) : BrandColors.teal.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: item.isFromManager ? .leading : .trailing)
                }
            }

            TextField(L10n.string(.supportMessageHint, language: appState.language), text: $message, axis: .vertical)
                .textFieldStyle(AppTextFieldStyle())
                .lineLimit(4...8)

            if sent {
                AppBanner(
                    message: L10n.string(.supportMessageSent, language: appState.language),
                    systemImage: "checkmark.circle",
                    tone: .success
                )
            }

            Button(L10n.string(.send, language: appState.language)) {
                Task { await send() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .appCard()
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string(.legalDocumentsTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)
            Link(L10n.string(.privacyPolicy, language: appState.language),
                 destination: LegalConfig.privacyPolicyURL(languageCode: appState.language.rawValue))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.tealDark)
            Link(L10n.string(.termsOfService, language: appState.language),
                 destination: LegalConfig.termsOfServiceURL(languageCode: appState.language.rawValue))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.tealDark)
        }
        .appCard()
    }

    private var faqItems: [FaqItem] {
        if isArabic {
            return [
                FaqItem(
                    question: "كيف أطلب رحلة؟",
                    answer: "افتح الخريطة، اختر نقطة الانطلاق والوجهة، ثم اضغط احجز رحلة."
                ),
                FaqItem(
                    question: "كيف ألغي رحلة؟",
                    answer: "يمكنك الإلغاء قبل بدء الرحلة من شاشة تتبع السائق."
                ),
                FaqItem(
                    question: "كيف أدفع؟",
                    answer: "الدفع نقداً للسائق بعد انتهاء الرحلة ما لم يُفعّل الدفع المسبق."
                ),
                FaqItem(
                    question: "كيف أبلّغ عن مشكلة؟",
                    answer: "استخدم الإبلاغ عن مشكلة أدناه أو تواصل مع الدعم مباشرة."
                ),
                FaqItem(
                    question: "متى يتم الرد على الشكاوى؟",
                    answer: "يراجع فريق الإدارة الشكاوى خلال 24–48 ساعة."
                ),
            ]
        }
        return [
            FaqItem(
                question: "How do I request a ride?",
                answer: "Open the map, pick pickup and destination, then tap Book ride."
            ),
            FaqItem(
                question: "How do I cancel a ride?",
                answer: "You can cancel before the trip starts from the track-driver screen."
            ),
            FaqItem(
                question: "How do I pay?",
                answer: "Pay the driver in cash after the trip unless prepaid wallet is enabled."
            ),
            FaqItem(
                question: "How do I report a problem?",
                answer: "Use Report a problem below or contact support directly."
            ),
            FaqItem(
                question: "When will complaints be answered?",
                answer: "Management reviews complaints within 24–48 hours."
            ),
        ]
    }

    private func contactButton(icon: String, value: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(BrandColors.teal)
                    .frame(width: 24)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.tealDark)
            }
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }

    private func reportButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(BrandColors.teal)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.tealDark)
            }
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }

    private func startWatchingMessages() {
        guard let uid = appState.currentUser?.uid else { return }
        messagesTask = Task {
            for await batch in SupportService().watchUserMessages(userId: uid) {
                guard !Task.isCancelled else { break }
                await MainActor.run { priorMessages = batch }
            }
        }
    }

    private func send() async {
        guard let user = appState.currentUser else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await SupportService().sendMessage(
                userId: user.uid,
                userRole: user.role,
                userName: user.name,
                phone: user.phone,
                message: message
            )
            message = ""
            sent = true
        } catch {
            sent = false
        }
    }

    private func submitReport(
        config: ReportSheetConfig,
        targetName: String,
        rideId: String,
        details: String
    ) async {
        guard let user = appState.currentUser else { return }
        let looksLikeUid = targetName.range(
            of: #"^[A-Za-z0-9]{20,}$"#,
            options: .regularExpression
        ) != nil
        let resolvedTargetUserId = looksLikeUid ? targetName : ""
        let resolvedTargetName = looksLikeUid ? "" : targetName
        do {
            _ = try await SupportService().createComplaint(
                userId: user.uid,
                userRole: user.role,
                userName: user.name,
                subject: config.subject,
                body: details,
                category: config.category,
                targetUserId: resolvedTargetUserId,
                targetRole: config.targetRole,
                targetName: resolvedTargetName,
                relatedRideId: rideId
            )
            reportSheet = nil
            reportSent = true
        } catch {
            reportSheet = nil
            reportError = true
        }
    }
}

private struct ReportSheetConfig: Identifiable {
    let id = UUID()
    let category: String
    let subject: String
    let targetRole: String
    let targetLabel: String
}

private struct ReportComplaintSheet: View {
    let config: ReportSheetConfig
    let language: AppLanguage
    let user: AppUser?
    let onSubmit: (String, String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var targetName = ""
    @State private var rideId = ""
    @State private var details = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                if !config.targetLabel.isEmpty {
                    TextField(config.targetLabel, text: $targetName)
                }
                TextField(
                    language == .arabic ? "رقم الرحلة (اختياري)" : "Ride ID (optional)",
                    text: $rideId
                )
                Section {
                    TextField(
                        language == .arabic ? "التفاصيل" : "Details",
                        text: $details,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                }
            }
            .navigationTitle(config.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, language: language)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.send, language: language)) {
                        Task {
                            isSubmitting = true
                            await onSubmit(
                                targetName.trimmingCharacters(in: .whitespacesAndNewlines),
                                rideId.trimmingCharacters(in: .whitespacesAndNewlines),
                                details.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(
                        isSubmitting ||
                        details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        user == nil
                    )
                }
            }
        }
    }
}
