import FirebaseAuth
import Foundation

enum AuthErrorMessages {
    static func message(for error: Error) -> String {
        if let authError = error as NSError?, authError.domain == AuthErrorDomain {
        guard let errorCode = AuthErrorCode(rawValue: authError.code) else {
                return authError.localizedDescription
            }
            switch errorCode {
            case .wrongPassword, .invalidCredential:
                return L10n.string(.wrongPassword)
            case .userNotFound:
                return L10n.string(.userNotFound)
            case .emailAlreadyInUse:
                return L10n.string(.phoneAlreadyRegistered)
            case .weakPassword:
                return L10n.string(.passwordMinLength)
            case .networkError:
                return L10n.string(.networkError)
            case .tooManyRequests:
                return L10n.string(.tooManyRequests)
            default:
                return authError.localizedDescription
            }
        }

        if let authError = error as? AuthErrorMessageProviding {
            return authError.message
        }

        return error.localizedDescription
    }
}

protocol AuthErrorMessageProviding: Error {
    var message: String { get }
}

struct AuthError: LocalizedError, AuthErrorMessageProviding {
    let code: String
    let message: String

    var errorDescription: String? { message }
}

extension AuthError {
    static let sessionActive = AuthError(
        code: "session-active",
        message: L10n.string(.sessionActive)
    )
}
