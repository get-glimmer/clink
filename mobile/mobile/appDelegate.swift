import UIKit
import UserNotifications
import GoogleSignIn
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        SupabaseClientManager.shared.initialize()
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.applicationIconBadgeNumber = 0

        // First lifecycle events (pre-login => Firebase only)
        AnalyticsService.shared.trackEvent("app_opened")
        AnalyticsService.shared.trackEvent("session_started")
        return true
    }

    // Handle the GoogleSignIn redirect back into the app.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
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
        let category = notification.request.content.categoryIdentifier
        AnalyticsService.shared.trackEvent("notification_received",
            properties: ["notification_type": category])
        completionHandler([.banner, .sound])
    }

    // Fired when the user taps a notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        AnalyticsService.shared.trackEvent("notification_clicked",
            source: "push",
            properties: ["notification_type": category])
        completionHandler()
    }
}
