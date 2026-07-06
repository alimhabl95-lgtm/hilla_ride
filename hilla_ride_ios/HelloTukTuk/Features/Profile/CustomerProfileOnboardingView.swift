import SwiftUI

struct CustomerProfileOnboardingView: View {
    @EnvironmentObject private var appState: AppState

    @State private var name = ""
    @State private var ageText = ""
    @State private var gender = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let genderOptions = ["male", "female"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.customerProfileTitle, language: appState.language))
                    .font(.largeTitle.bold())
                Text(L10n.string(.customerProfileHint, language: appState.language))
                    .foregroundStyle(.secondary)

                TextField(L10n.string(.fullName, language: appState.language), text: $name)
                    .textFieldStyle(AppTextFieldStyle())
                TextField(L10n.string(.age, language: appState.language), text: $ageText)
                    .textFieldStyle(AppTextFieldStyle())
                    .keyboardType(.numberPad)

                Picker(L10n.string(.gender, language: appState.language), selection: $gender) {
                    Text(L10n.string(.genderOptional, language: appState.language)).tag("")
                    Text(L10n.string(.genderMale, language: appState.language)).tag("male")
                    Text(L10n.string(.genderFemale, language: appState.language)).tag("female")
                }
                .pickerStyle(.menu)

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
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
        .onAppear {
            name = appState.currentUser?.name ?? ""
            if let age = appState.currentUser?.age, age > 0 {
                ageText = String(age)
            }
            gender = appState.currentUser?.gender ?? ""
        }
    }

    private func save() async {
        guard let user = appState.currentUser else { return }
        let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, age > 0 else {
            errorMessage = L10n.string(.profileFieldsRequired, language: appState.language)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.authService.saveUserProfile(
                role: user.role,
                name: name,
                age: age,
                gender: gender.isEmpty ? nil : gender
            )
            if let updated = try await UserRepository().fetchUser(uid: user.uid) {
                appState.setCurrentUser(updated)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
