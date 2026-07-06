import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var fcmToken: String?

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Non-fatal during Phase 0.
        }
    }

    func refreshToken() async {
        do {
            fcmToken = try await Messaging.messaging().token()
        } catch {
            fcmToken = nil
        }
    }

    func saveToken(for userID: String, role: UserRole) async {
        await refreshToken()
        guard let fcmToken, !fcmToken.isEmpty else { return }

        let firestore = Firestore.firestore()
        if role == .driver {
            try? await firestore.collection("drivers").document(userID).setData([
                "fcmToken": fcmToken,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } else {
            try? await firestore.collection("users").document(userID).setData([
                "fcmToken": fcmToken,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }
    }
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
