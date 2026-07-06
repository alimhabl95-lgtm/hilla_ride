import SwiftUI

struct MissingProfileRecoveryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.gold)
                Text(L10n.string(.restoreProfileTitle, language: appState.language))
                    .font(.title2.bold())
                Text(L10n.string(.restoreProfileMessage, language: appState.language))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                TextField(L10n.string(.fullName, language: appState.language), text: $name)
                    .textFieldStyle(AppTextFieldStyle())

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }

                Button(L10n.string(.restoreProfileAction, language: appState.language)) {
                    Task { await restore() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)

                Button(L10n.string(.useDifferentAccount, language: appState.language)) {
                    Task { try? await appState.signOut() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    private func restore() async {
        let role = appState.selectedMode ?? .customer
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.authService.restoreMissingProfile(role: role, name: name)
            if let uid = appState.authService.currentUID,
               let user = try await UserRepository().fetchUser(uid: uid) {
                appState.setCurrentUser(user)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
