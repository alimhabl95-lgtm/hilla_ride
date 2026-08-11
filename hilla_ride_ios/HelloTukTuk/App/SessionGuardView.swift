import SwiftUI

struct SessionGuardView<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    @ViewBuilder let content: () -> Content

    @State private var isChecking = true
    @State private var sessionTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isChecking {
                ProgressView(L10n.string(.loading, language: appState.language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrandColors.surface.ignoresSafeArea())
            } else {
                content()
            }
        }
        .task(id: appState.currentUser?.uid) {
            await validateAndWatchSession()
        }
        .onDisappear {
            sessionTask?.cancel()
        }
    }

    private func validateAndWatchSession() async {
        sessionTask?.cancel()
        defer { isChecking = false }

        guard let uid = appState.currentUser?.uid else {
            return
        }

        let sessionService = SessionService()
        let valid = (try? await sessionService.validateLocalSession(uid: uid)) ?? false
        if !valid {
            try? await appState.signOut()
            return
        }

        sessionTask = Task {
            for await _ in sessionService.watchRemoteSession(uid: uid) {
                guard !Task.isCancelled else { break }
                let stillValid = await sessionService.isSessionValid(uid: uid)
                if !stillValid {
                    try? await appState.signOut()
                    break
                }
            }
        }
    }
}

struct BlockedUserView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            Text(L10n.string(.accountBlockedTitle, language: appState.language))
                .font(.title2.bold())
            Text(L10n.string(.accountBlockedMessage, language: appState.language))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(L10n.string(.logout, language: appState.language)) {
                Task { try? await appState.signOut() }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }
}
