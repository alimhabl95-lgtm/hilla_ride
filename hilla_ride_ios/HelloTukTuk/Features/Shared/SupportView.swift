import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var appState: AppState

    @State private var contact = SupportContactInfo.defaults
    @State private var message = ""
    @State private var isSending = false
    @State private var sent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.supportTitle, language: appState.language))
                    .font(.largeTitle.bold())

                contactRow(icon: "phone.fill", value: contact.phone)
                contactRow(icon: "message.fill", value: contact.whatsapp)
                contactRow(icon: "envelope.fill", value: contact.email)

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
    }

    private func contactRow(icon: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(BrandColors.teal)
            Text(value)
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
