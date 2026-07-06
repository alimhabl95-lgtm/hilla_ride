import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.editProfileTitle, language: appState.language))
                    .font(.largeTitle.bold())

                TextField(L10n.string(.fullName, language: appState.language), text: $name)
                    .textFieldStyle(AppTextFieldStyle())

                if let user = appState.currentUser {
                    profileRow(
                        title: L10n.string(.phoneHint, language: appState.language),
                        value: user.phone
                    )
                }

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.tealDark)
                }

                Button(L10n.string(.saveProfileButton, language: appState.language)) {
                    Task { await save() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)
            }
            .padding(24)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = appState.currentUser?.name ?? ""
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func save() async {
        guard let uid = appState.currentUser?.uid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await UserRepository().updateUserName(uid: uid, name: name)
            if let user = try await UserRepository().fetchUser(uid: uid) {
                appState.setCurrentUser(user)
            }
            message = L10n.string(.profileSaved, language: appState.language)
        } catch {
            message = error.localizedDescription
        }
    }
}
