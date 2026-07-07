import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var ageText = ""
    @State private var gender = ""
    @State private var profilePhotoData: Data?
    @State private var isSaving = false
    @State private var message: String?
    @State private var showAlert = false
    @State private var saveSucceeded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.editProfileTitle, language: appState.language))
                    .font(.largeTitle.bold())

                if let user = appState.currentUser {
                    HStack(spacing: 16) {
                        ProfileAvatarView(
                            name: name.isEmpty ? user.name : name,
                            photoURL: user.profilePhotoUrl.isEmpty ? nil : user.profilePhotoUrl,
                            size: 72
                        )
                        PhotoUploadField(
                            title: L10n.string(.profilePhotoLabel, language: appState.language),
                            imageData: $profilePhotoData
                        )
                    }
                }

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
        .alert(L10n.string(.editProfileTitle, language: appState.language), isPresented: $showAlert) {
            Button(L10n.string(.ok, language: appState.language)) {
                if saveSucceeded { dismiss() }
            }
        } message: {
            Text(message ?? "")
        }
        .onAppear {
            guard let user = appState.currentUser else { return }
            name = user.name
            if user.age > 0 {
                ageText = String(user.age)
            }
            gender = user.gender ?? ""
        }
    }

    private func profileRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func save() async {
        guard let user = appState.currentUser else { return }
        let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, age > 0 else {
            message = L10n.string(.profileFieldsRequired, language: appState.language)
            saveSucceeded = false
            showAlert = true
            return
        }

        isSaving = true
        defer { isSaving = false }
        do {
            var photoUrl: String? = user.profilePhotoUrl.isEmpty ? nil : user.profilePhotoUrl
            if let profilePhotoData {
                photoUrl = try await StorageService().uploadUserProfilePhoto(uid: user.uid, data: profilePhotoData)
            }
            try await UserRepository().updateUserProfile(
                uid: user.uid,
                name: name,
                age: age,
                gender: gender.isEmpty ? nil : gender,
                profilePhotoUrl: photoUrl
            )
            if let updated = try await UserRepository().fetchUser(uid: user.uid) {
                appState.setCurrentUser(updated)
            }
            message = L10n.string(.profileSaved, language: appState.language)
            saveSucceeded = true
            showAlert = true
        } catch {
            message = error.localizedDescription
            saveSucceeded = false
            showAlert = true
        }
    }
}
