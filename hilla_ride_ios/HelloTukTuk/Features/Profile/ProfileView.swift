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
    @State private var showAlert = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let user = appState.currentUser {
                    VStack(alignment: .leading, spacing: 12) {
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
                    }
                    .appCard()

                    NavigationLink {
                        EditProfileView()
                    } label: {
                        Text(L10n.string(.editProfileTitle, language: appState.language))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    NavigationLink {
                        SupportView()
                    } label: {
                        Text(L10n.string(.helpSupportTitle, language: appState.language))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if user.role == .customer {
                        referralSection(for: user)
                    }

                    accountDeletionSection
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
        .alert(L10n.string(.changePasswordTitle, language: appState.language), isPresented: $showAlert) {
            Button(L10n.string(.ok, language: appState.language), role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .alert(L10n.string(.deleteAccount, language: appState.language), isPresented: $showDeleteConfirm) {
            Button(L10n.string(.cancel, language: appState.language), role: .cancel) {}
            Button(L10n.string(.deleteAccountConfirm, language: appState.language), role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text(L10n.string(.deleteAccountMessage, language: appState.language))
        }
    }

    private func referralSection(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.language == .arabic ? "برنامج الإحالة" : "Referral program")
                .font(.headline)
            if user.referralCode.isEmpty {
                Text(appState.language == .arabic
                     ? "سيظهر رمز الإحالة بعد تحديث الحساب."
                     : "Your referral code will appear after account sync.")
                    .font(.footnote)
                    .foregroundStyle(BrandColors.muted)
            } else {
                profileRow(
                    title: appState.language == .arabic ? "رمزك" : "Your code",
                    value: user.referralCode
                )
                Button {
                    UIPasteboard.general.string = user.referralCode
                } label: {
                    Text(appState.language == .arabic ? "نسخ الرمز" : "Copy code")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .appCard()
    }

    private var accountDeletionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.deleteAccountSectionTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.danger)

            Text(L10n.string(.deleteAccountMessage, language: appState.language))
                .font(.footnote)
                .foregroundStyle(BrandColors.muted)

            Button {
                showDeleteConfirm = true
            } label: {
                if isDeleting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(L10n.string(.deleteAccount, language: appState.language))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(SecondaryButtonStyle(destructive: true))
            .disabled(isDeleting)
        }
        .appCard()
        .padding(.top, 8)
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandColors.muted)
            Text(value)
                .font(.body)
                .foregroundStyle(BrandColors.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func savePassword() async {
        message = nil
        guard !currentPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            message = L10n.string(.passwordFieldsRequired, language: appState.language)
            isError = true
            showAlert = true
            return
        }
        guard newPassword == confirmPassword else {
            message = L10n.string(.passwordsDoNotMatch, language: appState.language)
            isError = true
            showAlert = true
            return
        }
        guard PhoneAuthCredentials.isValidPassword(newPassword) else {
            message = L10n.string(.passwordMinLength, language: appState.language)
            isError = true
            showAlert = true
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
            showAlert = true
        } catch {
            message = AuthErrorMessages.message(for: error)
            isError = true
            showAlert = true
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await appState.authService.deleteMyAccount()
            dismiss()
        } catch {
            message = L10n.string(.deleteAccountFailed, language: appState.language)
            isError = true
            showAlert = true
        }
    }
}
