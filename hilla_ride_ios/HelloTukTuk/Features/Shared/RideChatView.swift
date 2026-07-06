import SwiftUI

struct RideChatView: View {
    @EnvironmentObject private var appState: AppState
    let rideId: String

    @State private var messages: [RideMessage] = []
    @State private var draft = ""
    @State private var chatTask: Task<Void, Never>?

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
                .onChange(of: messages.count) { _, _ in
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
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle(L10n.string(.rideChatTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            RideAlertService.shared.setForegroundChatRideId(rideId)
            startWatching()
        }
        .onDisappear {
            RideAlertService.shared.setForegroundChatRideId(nil)
            chatTask?.cancel()
        }
    }

    private func chatBubble(_ message: RideMessage) -> some View {
        let isMine = message.senderId == appState.currentUser?.uid
        return VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
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
        guard let user = appState.currentUser else { return }
        let text = draft
        draft = ""
        try? await ChatService().sendRideMessage(
            rideId: rideId,
            senderId: user.uid,
            senderRole: user.role,
            senderName: user.name,
            text: text
        )
    }
}
