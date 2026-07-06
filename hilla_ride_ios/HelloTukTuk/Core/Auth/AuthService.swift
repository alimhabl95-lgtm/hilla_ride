import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

@MainActor
final class AuthService: ObservableObject {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")
    private let sessionService = SessionService()
    private let userRepository = UserRepository()

    func signIn(phoneRaw: String, password: String) async throws -> AppUser {
        let phone = PhoneAuthCredentials.normalizePhone(phoneRaw)
        let email = PhoneAuthCredentials.toAuthEmail(phone)

        let credential = try await auth.signIn(withEmail: email, password: password)
        let uid = credential.user.uid

        try await sessionService.claimSession(uid: uid)
        guard let user = try await userRepository.fetchUser(uid: uid) else {
            throw AuthError(code: "profile-missing", message: "Account profile not found.")
        }
        return user
    }

    func signUpCustomer(
        phoneRaw: String,
        password: String,
        fullName: String,
        email: String?
    ) async throws {
        _ = try await signUp(
            phoneRaw: phoneRaw,
            password: password,
            fullName: fullName,
            role: .customer,
            email: email,
            age: 18
        )
    }

    func signUpDriverAccount(
        phoneRaw: String,
        password: String,
        fullName: String,
        age: Int
    ) async throws -> String {
        try await signUp(
            phoneRaw: phoneRaw,
            password: password,
            fullName: fullName,
            role: .driver,
            email: nil,
            age: age
        )
    }

    func resetPasswordByPhone(phoneRaw: String, newPassword: String) async throws {
        guard PhoneAuthCredentials.isValidIraqiPhone(phoneRaw) else {
            throw AuthError(code: "invalid-phone", message: L10n.string(.phoneNumberInvalid))
        }
        guard PhoneAuthCredentials.isValidPassword(newPassword) else {
            throw AuthError(code: "weak-password", message: L10n.string(.passwordMinLength))
        }

        let phone = PhoneAuthCredentials.normalizePhone(phoneRaw)
        do {
            _ = try await functions.httpsCallable("resetPasswordByPhone").call([
                "phone": phone,
                "newPassword": newPassword
            ])
        } catch let error as NSError {
            throw mapFunctionsError(error)
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = auth.currentUser, let email = user.email else {
            throw AuthError(code: "internal", message: "Not signed in.")
        }
        guard PhoneAuthCredentials.isValidPassword(newPassword) else {
            throw AuthError(code: "weak-password", message: L10n.string(.passwordMinLength))
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
        try await user.updatePassword(newPassword)
    }

    @discardableResult
    func signUp(
        phoneRaw: String,
        password: String,
        fullName: String,
        role: UserRole,
        email: String?,
        age: Int
    ) async throws -> String {
        guard PhoneAuthCredentials.isValidPassword(password) else {
            throw AuthError(code: "weak-password", message: L10n.string(.passwordMinLength))
        }

        let phone = PhoneAuthCredentials.normalizePhone(phoneRaw)
        let authEmail = PhoneAuthCredentials.toAuthEmail(phone)

        let credential: AuthDataResult
        do {
            credential = try await auth.createUser(withEmail: authEmail, password: password)
        } catch let error as NSError {
            if AuthErrorCode(rawValue: error.code) == .emailAlreadyInUse {
                credential = try await retrySignupAfterReleasedPhone(
                    phone: phone,
                    authEmail: authEmail,
                    password: password
                )
            } else {
                throw error
            }
        }

        let user = credential.user

        do {
            let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty, user.displayName != trimmedName {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = trimmedName
                try await changeRequest.commitChanges()
            }

            try await userRepository.createUserProfile(
                uid: user.uid,
                phone: phone,
                role: role,
                fullName: trimmedName,
                email: email,
                age: age
            )
            try await sessionService.claimSession(uid: user.uid)
            return user.uid
        } catch {
            try? await user.delete()
            throw error
        }
    }

    private func mapFunctionsError(_ error: NSError) -> Error {
        if error.domain == FunctionsErrorDomain {
            switch FunctionsErrorCode(rawValue: error.code) {
            case .notFound:
                return AuthError(code: "user-not-found", message: L10n.string(.userNotFound))
            case .internal:
                return AuthError(code: "internal", message: L10n.string(.passwordResetFailed))
            default:
                return AuthError(code: "internal", message: error.localizedDescription)
            }
        }
        return error
    }

    func signOut() async throws {
        if let uid = auth.currentUser?.uid {
            await sessionService.clearSession(uid: uid)
        }
        try auth.signOut()
    }

    private func retrySignupAfterReleasedPhone(
        phone: String,
        authEmail: String,
        password: String
    ) async throws -> AuthDataResult {
        let phoneKey = phone.filter(\.isNumber)
        let released = try await firestore.collection("released_phones").document(phoneKey).getDocument()
        guard released.exists else {
            throw AuthError(code: "email-already-in-use", message: L10n.string(.phoneAlreadyRegistered))
        }

        do {
            _ = try await functions.httpsCallable("cleanupReleasedPhoneAuth").call(["phone": phone])
        } catch {
            throw AuthError(
                code: "email-already-in-use",
                message: "This phone number was deleted but is not ready for registration yet. Try again later."
            )
        }

        do {
            return try await auth.createUser(withEmail: authEmail, password: password)
        } catch {
            throw AuthError(code: "email-already-in-use", message: L10n.string(.phoneAlreadyRegistered))
        }
    }
}
