import Foundation
import UIKit
import UserNotifications
import Supabase

class PushNotificationService {
    static let shared = PushNotificationService()

    private var supabase: SupabaseClient? {
        SupabaseClientManager.shared.client
    }

    private init() {}

    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func saveDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs device token: \(token)")

        guard let supabase = supabase else { return }

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString

            let row = DeviceTokenRow(
                user_id: userId,
                token: token,
                platform: "ios"
            )

            try await supabase
                .from("device_tokens")
                .upsert(row, onConflict: "user_id, token")
                .execute()

            print("Device token saved to Supabase")
        } catch {
            print("Failed to save device token: \(error)")
        }
    }

    func removeDeviceToken() async {
        guard let supabase = supabase else { return }

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString

            try await supabase
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .execute()

            print("Device tokens removed for user")
        } catch {
            print("Failed to remove device token: \(error)")
        }
    }
}

private struct DeviceTokenRow: Encodable {
    let user_id: String
    let token: String
    let platform: String
}
