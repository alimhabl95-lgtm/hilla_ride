import SwiftUI

struct RideChatView: View {
    @EnvironmentObject private var appState: AppState
    let rideId: String

    @State private var messages: [RideMessage] = []
    @State private var draft = ""
    @State private var chatTask: Task<Void, Never>?
    @StateObject private var voiceRecorder = VoiceRecorder()
    @State private var isSendingVoice = false

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

            if voiceRecorder.isRecording {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                    Text("\(L10n.string(.recordingVoice, language: appState.language)) \(VoiceMessageBubble.formatDuration(voiceRecorder.elapsedMs))")
                    Spacer()
                    Button(L10n.string(.cancel, language: appState.language)) {
                        voiceRecorder.cancelRecording()
                    }
                    Button(L10n.string(.send, language: appState.language)) {
                        Task { await stopAndSendVoice() }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task { try? voiceRecorder.startRecording() }
                    } label: {
                        Image(systemName: "mic.fill")
                    }
                    .disabled(isSendingVoice)

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
            voiceRecorder.cancelRecording()
        }
    }

    @ViewBuilder
    private func chatBubble(_ message: RideMessage) -> some View {
        let isMine = message.senderId == appState.currentUser?.uid
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            Text(message.senderName)
                .font(.caption)
                .foregroundStyle(.secondary)
            if message.isVoice {
                VoiceMessageBubble(
                    voiceUrl: message.voiceUrl,
                    durationMs: message.voiceDurationMs,
                    isMine: isMine
                )
            } else {
                Text(message.text)
                    .padding(10)
                    .background(isMine ? BrandColors.teal.opacity(0.2) : Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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

    private func stopAndSendVoice() async {
        guard let user = appState.currentUser,
              let recording = voiceRecorder.stopRecording() else { return }
        isSendingVoice = true
        defer { isSendingVoice = false }
        do {
            let messageId = UUID().uuidString
            let data = try Data(contentsOf: recording.url)
            let voiceUrl = try await StorageService().uploadRideVoiceMessage(
                rideId: rideId,
                messageId: messageId,
                data: data
            )
            try await ChatService().sendRideVoiceMessage(
                rideId: rideId,
                senderId: user.uid,
                senderRole: user.role,
                senderName: user.name,
                voiceUrl: voiceUrl,
                voiceDurationMs: recording.durationMs
            )
            try? FileManager.default.removeItem(at: recording.url)
        } catch {
            // Non-fatal.
        }
    }
}
