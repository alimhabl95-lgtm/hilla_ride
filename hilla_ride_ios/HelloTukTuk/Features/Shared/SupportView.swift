import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appState: AppState

    @State private var contact = SupportContactInfo.defaults
    @State private var message = ""
    @State private var isSending = false
    @State private var sent = false
    @State private var priorMessages: [SupportMessage] = []
    @State private var messagesTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.supportTitle, language: appState.language))
                    .font(.largeTitle.bold())

                contactRow(icon: "phone.fill", value: contact.phone)
                contactRow(icon: "message.fill", value: contact.whatsapp)
                contactRow(icon: "envelope.fill", value: contact.email)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string(.legalDocumentsTitle, language: appState.language))
                        .font(.headline)
                    Link(L10n.string(.privacyPolicy, language: appState.language),
                         destination: LegalConfig.privacyPolicyURL(languageCode: appState.language.rawValue))
                    Link(L10n.string(.termsOfService, language: appState.language),
                         destination: LegalConfig.termsOfServiceURL(languageCode: appState.language.rawValue))
                }

                if !priorMessages.isEmpty {
                    Text(L10n.string(.supportPreviousMessages, language: appState.language))
                        .font(.headline)
                    ForEach(priorMessages) { item in
                        VStack(alignment: item.isFromManager ? .leading : .trailing, spacing: 4) {
                            Text(item.message)
                                .padding(10)
                                .background(item.isFromManager ? Color.gray.opacity(0.15) : BrandColors.teal.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .frame(maxWidth: .infinity, alignment: item.isFromManager ? .leading : .trailing)
                    }
                }

                TextField(L10n.string(.supportMessageHint, language: appState.language), text: $message, axis: .vertical)
                    .textFieldStyle(AppTextFieldStyle())
                    .lineLimit(4...8)

                if sent {
                    Text(L10n.string(.supportMessageSent, language: appState.language))
                        .foregroundStyle(BrandColors.tealDark)
                }

                Button(L10n.string(.send, language: appState.language)) {
                    Task { await send() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    }

    private func contactRow(icon: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(BrandColors.teal)
            Text(value)
        }
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
}
