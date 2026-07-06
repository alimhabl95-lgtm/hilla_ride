import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = appState.currentUser {
                    profileRow(
                        title: L10n.string(.fullName, language: appState.language),
                        value: user.name
                    )
                    profileRow(
                        title: L10n.string(.phoneHint, language: appState.language),
                        value: user.phone
                    )
                    profileRow(
                        title: L10n.string(.accountType, language: appState.language),
                        value: user.role == .driver
                            ? L10n.string(.roleDriver, language: appState.language)
                            : L10n.string(.roleCustomer, language: appState.language)
                    )

                    if let driver = appState.currentDriver, user.role == .driver {
                        profileRow(
                            title: L10n.string(.driverStatus, language: appState.language),
                            value: driver.approvalStatus.rawValue.capitalized
                        )
                    }

                    NavigationLink {
                        EditProfileView()
                    } label: {
                        Text(L10n.string(.editProfileTitle, language: appState.language))
                            .font(.subheadline.bold())
                            .foregroundStyle(BrandColors.tealDark)
                    }
                }

                Divider().padding(.vertical, 8)

                Text(L10n.string(.changePasswordTitle, language: appState.language))
                    .font(.headline)

                SecureField(L10n.string(.currentPassword, language: appState.language), text: $currentPassword)
                    .textFieldStyle(AppTextFieldStyle())

                SecureField(L10n.string(.newPassword, language: appState.language), text: $newPassword)
                    .textFieldStyle(AppTextFieldStyle())

                SecureField(L10n.string(.confirmPassword, language: appState.language), text: $confirmPassword)
                    .textFieldStyle(AppTextFieldStyle())

                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(isError ? .red : BrandColors.tealDark)
                }

                Button(L10n.string(.savePasswordButton, language: appState.language)) {
                    Task { await savePassword() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving)

                Button(L10n.string(.logout, language: appState.language)) {
                    Task {
                        try? await appState.signOut()
                        dismiss()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationTitle(L10n.string(.profileTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savePassword() async {
        message = nil
        guard !currentPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            message = L10n.string(.passwordFieldsRequired, language: appState.language)
            isError = true
            return
        }
        guard newPassword == confirmPassword else {
            message = L10n.string(.passwordsDoNotMatch, language: appState.language)
            isError = true
            return
        }
        guard PhoneAuthCredentials.isValidPassword(newPassword) else {
            message = L10n.string(.passwordMinLength, language: appState.language)
            isError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await appState.authService.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            message = L10n.string(.passwordChangedMessage, language: appState.language)
            isError = false
        } catch {
            message = AuthErrorMessages.message(for: error)
            isError = true
        }
    }
}
