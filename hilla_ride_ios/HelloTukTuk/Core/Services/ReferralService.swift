import FirebaseFunctions
import Foundation

enum ReferralService {
    static func applyReferralCode(_ code: String) async throws {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }

        let callable = Functions.functions(region: "us-central1")
            .httpsCallable("applyReferralCode")
        _ = try await callable.call(["referralCode": trimmed])
    }
}
