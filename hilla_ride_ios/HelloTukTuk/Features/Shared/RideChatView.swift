import SwiftUI

struct RideChatView: View {
    @EnvironmentObject private var appState: AppState
    let rideId: String

    @State private var messages: [RideMessage] = []
    @State private var draft = ""
    @State private var chatTask: Task<Void, Never>?
    @State private var sendErrorMessage: String?
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            chatBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(L10n.string(.chatHint, language: appState.language), text: $draft)
                    .textFieldStyle(AppTextFieldStyle())
                Button(L10n.string(.send, language: appState.language)) {
                    Task { await sendMessage() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle(L10n.string(.rideChatTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            L10n.string(.messageSendFailed, language: appState.language),
            isPresented: Binding(
                get: { sendErrorMessage != nil },
                set: { if !$0 { sendErrorMessage = nil } }
            )
        ) {
            Button(L10n.string(.ok, language: appState.language), role: .cancel) {
                sendErrorMessage = nil
            }
        } message: {
            Text(sendErrorMessage ?? "")
        }
        .onAppear {
            RideAlertService.shared.setForegroundChatRideId(rideId)
            startWatching()
        }
        .onDisappear {
            RideAlertService.shared.setForegroundChatRideId(nil)
            chatTask?.cancel()
        }
    }

    @ViewBuilder
    private func chatBubble(_ message: RideMessage) -> some View {
        let isMine = message.senderId == currentSenderIdentity()?.uid
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            Text(message.senderName)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(message.text)
                .padding(10)
                .background(isMine ? BrandColors.teal.opacity(0.2) : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    private func startWatching() {
        chatTask = Task {
            for await batch in ChatService().watchRideMessages(rideId: rideId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { messages = batch }
            }
        }
    }

    private func sendMessage() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        guard let identity = currentSenderIdentity() else {
            sendErrorMessage = L10n.string(.messageSendFailed, language: appState.language)
            return
        }

        draft = ""
        isSending = true
        defer { isSending = false }

        do {
            try await ChatService().sendRideMessage(
                rideId: rideId,
                senderId: identity.uid,
                senderRole: identity.role,
                senderName: identity.name,
                text: text
            )
        } catch {
            draft = text
            sendErrorMessage = error.localizedDescription
        }
    }

    private func currentSenderIdentity() -> (uid: String, role: UserRole, name: String)? {
        if let user = appState.currentUser {
            let name = user.name.isEmpty ? (appState.currentDriver?.name ?? user.name) : user.name
            return (user.uid, user.role, name)
        }
        if let driver = appState.currentDriver {
            return (driver.uid, .driver, driver.name)
        }
        if let uid = appState.authService.currentUID {
            return (uid, appState.selectedMode ?? .customer, "")
        }
        return nil
    }
}
