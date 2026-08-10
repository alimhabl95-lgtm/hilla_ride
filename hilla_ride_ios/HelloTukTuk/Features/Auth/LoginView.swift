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
    @State private var showPassword = false

    private var selectedMode: UserRole {
        appState.selectedMode ?? .customer
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string(.loginTitle, language: appState.language))
                        .font(.largeTitle.bold())
                        .foregroundStyle(BrandColors.navy)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)

                    Text(selectedMode == .driver
                         ? L10n.string(.roleDriver, language: appState.language)
                         : L10n.string(.roleCustomer, language: appState.language))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BrandColors.muted)
                        .frame(maxWidth: .infinity, alignment: .center)

                    labeledField(systemImage: "phone") {
                        TextField(
                            L10n.string(.phoneHint, language: appState.language),
                            text: $phone
                        )
                        .keyboardType(.phonePad)
                        .textInputAutocapitalization(.never)
                    }

                    labeledField(systemImage: "lock") {
                        HStack(spacing: 8) {
                            Group {
                                if showPassword {
                                    TextField(
                                        L10n.string(.passwordLabel, language: appState.language),
                                        text: $password
                                    )
                                } else {
                                    SecureField(
                                        L10n.string(.passwordLabel, language: appState.language),
                                        text: $password
                                    )
                                }
                            }
                            .textInputAutocapitalization(.never)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye" : "eye.slash")
                                    .foregroundStyle(BrandColors.muted)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Toggle(isOn: $rememberMe) {
                            Text(L10n.string(.rememberMe, language: appState.language))
                                .font(.subheadline)
                        }
                        .toggleStyle(CheckboxToggleStyle())
                        .tint(BrandColors.teal)

                        Spacer()

                        Button(L10n.string(.forgotPassword, language: appState.language)) {
                            showForgotPassword = true
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrandColors.tealDark)
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
                    .padding(.top, 4)

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
        .navigationTitle(L10n.string(.appTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BrandColors.teal, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LanguageToggle()
            }
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(BrandColors.tealDark)
                .frame(width: 22)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                .stroke(BrandColors.border, lineWidth: 1)
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

/// Simple checkbox-style toggle for Remember me row.
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(configuration.isOn ? BrandColors.teal : BrandColors.muted)
                    .font(.title3)
                configuration.label
                    .foregroundStyle(BrandColors.navy)
            }
        }
        .buttonStyle(.plain)
    }
}
