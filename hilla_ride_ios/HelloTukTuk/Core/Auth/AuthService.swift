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
        guard let uid = credential.user?.uid else {
            throw AuthError(code: "internal", message: "Login failed.")
        }

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
        try await signUp(
            phoneRaw: phoneRaw,
            password: password,
            fullName: fullName,
            role: .customer,
            email: email,
            age: 18
        )
    }

    func signUp(
        phoneRaw: String,
        password: String,
        fullName: String,
        role: UserRole,
        email: String?,
        age: Int
    ) async throws {
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

        guard let user = credential.user else {
            throw AuthError(code: "internal", message: "Registration failed.")
        }

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
        } catch {
            try? await user.delete()
            throw error
        }
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
