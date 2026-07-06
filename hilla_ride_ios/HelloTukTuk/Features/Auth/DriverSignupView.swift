import SwiftUI

struct DriverSignupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var age = ""
    @State private var vehiclePlate = ""
    @State private var vehicleColor = ""
    @State private var idPhotoData: Data?
    @State private var profilePhotoData: Data?
    @State private var acceptedTerms = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string(.driverSignupTitle, language: appState.language))
                        .font(.largeTitle.bold())

                    Text(L10n.string(.driverSignupSubtitle, language: appState.language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField(L10n.string(.fullName, language: appState.language), text: $fullName)
                        .textFieldStyle(AppTextFieldStyle())

                    TextField(L10n.string(.phoneHint, language: appState.language), text: $phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(AppTextFieldStyle())

                    TextField(L10n.string(.age, language: appState.language), text: $age)
                        .keyboardType(.numberPad)
                        .textFieldStyle(AppTextFieldStyle())

                    SecureField(L10n.string(.passwordLabel, language: appState.language), text: $password)
                        .textFieldStyle(AppTextFieldStyle())

                    TextField(L10n.string(.vehiclePlate, language: appState.language), text: $vehiclePlate)
                        .textInputAutocapitalization(.characters)
                        .textFieldStyle(AppTextFieldStyle())

                    TextField(L10n.string(.vehicleColor, language: appState.language), text: $vehicleColor)
                        .textFieldStyle(AppTextFieldStyle())

                    PhotoUploadField(
                        title: L10n.string(.idPhotoLabel, language: appState.language),
                        imageData: $idPhotoData
                    )

                    PhotoUploadField(
                        title: L10n.string(.profilePhotoLabel, language: appState.language),
                        imageData: $profilePhotoData
                    )

                    Toggle(isOn: $acceptedTerms) {
                        Text(L10n.string(.acceptTerms, language: appState.language))
                            .font(.footnote)
                    }
                    .tint(BrandColors.teal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(L10n.string(.submitDriverApplication, language: appState.language)) {
                        Task { await submit() }
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
        .alert(L10n.string(.driverSignupSuccessTitle, language: appState.language), isPresented: $showSuccess) {
            Button(L10n.string(.goToLogin, language: appState.language)) {
                dismiss()
            }
        } message: {
            Text(L10n.string(.driverSignupSuccessMessage, language: appState.language))
        }
    }

    private func submit() async {
        errorMessage = nil

        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = L10n.string(.nameRequired, language: appState.language)
            return
        }
        guard PhoneAuthCredentials.isValidIraqiPhone(phone) else {
            errorMessage = L10n.string(.phoneNumberInvalid, language: appState.language)
            return
        }
        guard let ageValue = Int(age.trimmingCharacters(in: .whitespacesAndNewlines)), ageValue >= 18 else {
            errorMessage = L10n.string(.driverMinAge, language: appState.language)
            return
        }
        guard PhoneAuthCredentials.isValidPassword(password) else {
            errorMessage = L10n.string(.passwordMinLength, language: appState.language)
            return
        }
        guard !vehiclePlate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = L10n.string(.vehiclePlateRequired, language: appState.language)
            return
        }
        guard !vehicleColor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = L10n.string(.vehicleColorRequired, language: appState.language)
            return
        }
        guard idPhotoData != nil, profilePhotoData != nil else {
            errorMessage = L10n.string(.registrationPhotosRequired, language: appState.language)
            return
        }
        guard acceptedTerms else {
            errorMessage = L10n.string(.acceptTerms, language: appState.language)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let uid = try await appState.authService.signUpDriverAccount(
                phoneRaw: phone,
                password: password,
                fullName: trimmedName,
                age: ageValue
            )

            let normalizedPhone = PhoneAuthCredentials.normalizePhone(phone)
            let storage = StorageService()
            let idURL = try await storage.uploadDriverDocument(
                uid: uid,
                data: idPhotoData!,
                fileName: "id_photo.jpg"
            )
            let profileURL = try await storage.uploadDriverDocument(
                uid: uid,
                data: profilePhotoData!,
                fileName: "profile_photo.jpg"
            )

            let driverRepo = DriverRepository()
            try await driverRepo.submitRegistration(
                phone: normalizedPhone,
                name: trimmedName,
                vehicleType: "Tuk-Tuk",
                vehiclePlate: vehiclePlate.trimmingCharacters(in: .whitespacesAndNewlines),
                vehicleColor: vehicleColor.trimmingCharacters(in: .whitespacesAndNewlines),
                idPhotoURL: idURL,
                profilePhotoURL: profileURL
            )

            try await appState.authService.signOut()
            showSuccess = true
        } catch {
            errorMessage = AuthErrorMessages.message(for: error)
        }
    }
}
