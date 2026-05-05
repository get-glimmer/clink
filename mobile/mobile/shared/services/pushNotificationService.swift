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

    /// Send a nudge to remind someone to complete their tasks
    /// - Parameters:
    ///   - targetUserId: The user to nudge
    ///   - type: "personal" or "challenge"
    ///   - challengeTitle: Optional challenge name for challenge nudges
    func sendTaskNudge(to targetUserId: String, type: String, challengeTitle: String? = nil) async {
        guard let supabase = supabase else { return }

        do {
            let session = try await supabase.auth.session
            let senderName = try await getSenderName(userId: session.user.id.uuidString)

            let body: String
            if type == "challenge", let title = challengeTitle {
                body = "\(senderName) is reminding you to finish your tasks in \(title)"
            } else {
                body = "\(senderName) is reminding you to finish your tasks today"
            }

            try await supabase.functions.invoke(
                "send-push",
                options: .init(body: [
                    "user_id": targetUserId,
                    "title": "Task Reminder",
                    "body": body
                ] as [String: String])
            )
        } catch {
            print("Failed to send nudge: \(error)")
        }
    }

    private func getSenderName(userId: String) async throws -> String {
        guard let supabase = supabase else { return "Someone" }

        struct NameRow: Decodable {
            let name: String?
            let username: String?
        }

        let response: NameRow = try await supabase
            .from("profiles")
            .select("name, username")
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        return response.name ?? response.username ?? "Someone"
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
