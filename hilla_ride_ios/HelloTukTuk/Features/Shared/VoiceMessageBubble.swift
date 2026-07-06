import SwiftUI

struct VoiceMessageBubble: View {
    @EnvironmentObject private var appState: AppState
    let voiceUrl: String
    let durationMs: Int
    let isMine: Bool

    @StateObject private var player = VoicePlayer()
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await play() }
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
            }
            .disabled(isLoading || voiceUrl.isEmpty)
            Text(Self.formatDuration(durationMs))
                .font(.subheadline.monospacedDigit())
        }
        .padding(10)
        .background(isMine ? BrandColors.teal.opacity(0.2) : Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func formatDuration(_ ms: Int) -> String {
        let totalSeconds = max(ms, 0) / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func play() async {
        guard !voiceUrl.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data = try await StorageService().downloadData(from: voiceUrl)
            try player.play(data: data)
        } catch {
            // Non-fatal playback failure.
        }
    }
}
