import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showSignup = false
    @State private var showForgotPassword = false

    var body: some View {
        LoginView(showSignup: $showSignup, showForgotPassword: $showForgotPassword)
            .navigationDestination(isPresented: $showSignup) {
                if appState.selectedMode == .driver {
                    DriverSignupView()
                } else {
                    SignupView()
                }
            }
            .navigationDestination(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showSignup: Bool
    @Binding var showForgotPassword: Bool

    @State private var phone = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var selectedMode: UserRole {
        appState.selectedMode ?? .customer
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string(.loginTitle, language: appState.language))
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(selectedMode == .driver
                         ? L10n.string(.roleDriver, language: appState.language)
                         : L10n.string(.roleCustomer, language: appState.language))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    TextField(L10n.string(.phoneHint, language: appState.language), text: $phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(AppTextFieldStyle())

                    SecureField(L10n.string(.passwordLabel, language: appState.language), text: $password)
                        .textFieldStyle(AppTextFieldStyle())

                    HStack {
                        Toggle(L10n.string(.rememberMe, language: appState.language), isOn: $rememberMe)
                            .tint(BrandColors.teal)
                        Spacer()
                        Button(L10n.string(.forgotPassword, language: appState.language)) {
                            showForgotPassword = true
                        }
                        .font(.footnote)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(L10n.string(.loginButton, language: appState.language)) {
                        Task { await login() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)

                    Button(L10n.string(.createAccountButton, language: appState.language)) {
                        showSignup = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(24)
            }
            .background(BrandColors.surface.ignoresSafeArea())

            LoadingOverlay(isLoading: isLoading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LanguageToggle()
            }
        }
    }

    private func login() async {
        errorMessage = nil

        guard PhoneAuthCredentials.isValidIraqiPhone(phone) else {
            errorMessage = L10n.string(.phoneNumberInvalid, language: appState.language)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await appState.authService.signIn(phoneRaw: phone, password: password)
            appState.setCurrentUser(user)
        } catch {
            errorMessage = AuthErrorMessages.message(for: error)
        }
    }
}
