import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        SupabaseClientManager.shared.initialize()
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.applicationIconBadgeNumber = 0
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("[APNs] Got device token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        Task {
            await PushNotificationService.shared.saveDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] Failed to register: \(error)")
    }

    // Show notifications even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
