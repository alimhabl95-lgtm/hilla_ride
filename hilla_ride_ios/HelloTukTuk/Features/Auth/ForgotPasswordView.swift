import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var phone = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string(.forgotPasswordTitle, language: appState.language))
                        .font(.largeTitle.bold())

                    Text(L10n.string(.forgotPasswordHint, language: appState.language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(L10n.string(.phoneHint, language: appState.language), text: $phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(AppTextFieldStyle())

                    SecureField(L10n.string(.newPassword, language: appState.language), text: $newPassword)
                        .textFieldStyle(AppTextFieldStyle())

                    SecureField(L10n.string(.confirmPassword, language: appState.language), text: $confirmPassword)
                        .textFieldStyle(AppTextFieldStyle())

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(L10n.string(.resetPasswordButton, language: appState.language)) {
                        Task { await resetPassword() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                }
                .padding(24)
            }
            .background(BrandColors.surface.ignoresSafeArea())

            LoadingOverlay(isLoading: isLoading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.string(.passwordChangedTitle, language: appState.language), isPresented: $showSuccess) {
            Button(L10n.string(.goToLogin, language: appState.language)) {
                dismiss()
            }
        } message: {
            Text(L10n.string(.passwordChangedMessage, language: appState.language))
        }
    }

    private func resetPassword() async {
        errorMessage = nil

        guard PhoneAuthCredentials.isValidIraqiPhone(phone) else {
            errorMessage = L10n.string(.phoneNumberInvalid, language: appState.language)
            return
        }
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = L10n.string(.passwordFieldsRequired, language: appState.language)
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = L10n.string(.passwordsDoNotMatch, language: appState.language)
            return
        }
        guard PhoneAuthCredentials.isValidPassword(newPassword) else {
            errorMessage = L10n.string(.passwordMinLength, language: appState.language)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await appState.authService.resetPasswordByPhone(phoneRaw: phone, newPassword: newPassword)
            showSuccess = true
        } catch {
            errorMessage = AuthErrorMessages.message(for: error)
        }
    }
}
