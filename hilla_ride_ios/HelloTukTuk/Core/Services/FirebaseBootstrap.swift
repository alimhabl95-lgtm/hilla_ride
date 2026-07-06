import FirebaseCore
import FirebaseMessaging
import GoogleMaps
import UIKit
import UserNotifications

enum FirebaseBootstrap {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if MapsConfig.isConfigured {
            GMSServices.provideAPIKey(MapsConfig.apiKey)
        }
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}
