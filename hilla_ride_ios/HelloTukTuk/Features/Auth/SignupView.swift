import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var password = ""
    @State private var acceptedTerms = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private var selectedMode: UserRole {
        appState.selectedMode ?? .customer
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string(.signupTitle, language: appState.language))
                        .font(.largeTitle.bold())

                    if selectedMode == .driver {
                        Text(L10n.string(.driverSignupPhaseNote, language: appState.language))
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .padding(.bottom, 4)
                    }

                    TextField(L10n.string(.fullName, language: appState.language), text: $fullName)
                        .textFieldStyle(AppTextFieldStyle())

                    TextField(L10n.string(.phoneHint, language: appState.language), text: $phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(AppTextFieldStyle())

                    if selectedMode == .customer {
                        TextField(L10n.string(.emailOptional, language: appState.language), text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .textFieldStyle(AppTextFieldStyle())
                    }

                    SecureField(L10n.string(.passwordLabel, language: appState.language), text: $password)
                        .textFieldStyle(AppTextFieldStyle())

                    Text(L10n.string(.passwordMinLength, language: appState.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $acceptedTerms) {
                        Text(L10n.string(.acceptTerms, language: appState.language))
                            .font(.footnote)
                    }
                    .tint(BrandColors.teal)

                    HStack {
                        Link(L10n.string(.privacyPolicy, language: appState.language),
                             destination: LegalConfig.privacyPolicyURL(languageCode: appState.language.rawValue))
                        Link(L10n.string(.termsOfService, language: appState.language),
                             destination: LegalConfig.termsOfServiceURL(languageCode: appState.language.rawValue))
                    }
                    .font(.footnote)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(L10n.string(.createAccountButton, language: appState.language)) {
                        Task { await signup() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading || selectedMode == .driver)
                }
                .padding(24)
            }
            .background(BrandColors.surface.ignoresSafeArea())

            LoadingOverlay(isLoading: isLoading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.string(.signupSuccessTitle, language: appState.language), isPresented: $showSuccess) {
            Button(L10n.string(.goToLogin, language: appState.language)) {
                dismiss()
            }
        } message: {
            Text(L10n.string(.signupSuccessMessage, language: appState.language))
        }
    }

    private func signup() async {
        errorMessage = nil

        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = L10n.string(.nameRequired, language: appState.language)
            return
        }
        guard PhoneAuthCredentials.isValidIraqiPhone(phone) else {
            errorMessage = L10n.string(.phoneNumberInvalid, language: appState.language)
            return
        }
        guard PhoneAuthCredentials.isValidPassword(password) else {
            errorMessage = L10n.string(.passwordMinLength, language: appState.language)
            return
        }
        guard acceptedTerms else {
            errorMessage = L10n.string(.acceptTerms, language: appState.language)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await appState.authService.signUpCustomer(
                phoneRaw: phone,
                password: password,
                fullName: fullName,
                email: email
            )
            try await appState.authService.signOut()
            showSuccess = true
        } catch {
            errorMessage = AuthErrorMessages.message(for: error)
        }
    }
}
