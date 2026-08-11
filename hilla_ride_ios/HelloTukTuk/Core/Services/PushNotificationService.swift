import FirebaseFirestore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published private(set) var fcmToken: String?

    override private init() {
        super.init()
        Messaging.messaging().delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Non-fatal.
        }
    }

    func refreshToken() async {
        do {
            fcmToken = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await Messaging.messaging().token()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 20_000_000_000)
                    throw CancellationError()
                }
                guard let token = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return token
            }
        } catch {
            fcmToken = nil
        }
    }

    func saveToken(for userID: String, role: UserRole) async {
        await refreshToken()
        guard let fcmToken, !fcmToken.isEmpty else { return }

        let firestore = Firestore.firestore()
        let payload: [String: Any] = [
            "fcmToken": fcmToken,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
            "fcmUpdatedAt": FieldValue.serverTimestamp()
        ]

        if role == .driver {
            try? await firestore.collection("drivers").document(userID).setData(payload, merge: true)
        } else {
            try? await firestore.collection("users").document(userID).setData(payload, merge: true)
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

extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        Task { @MainActor in
            self.fcmToken = fcmToken
        }
    }
}
