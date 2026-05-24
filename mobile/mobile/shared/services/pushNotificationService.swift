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
            Task { await PushNotificationService.shared.seedNotificationPreferences() }
        }
    }

    /// Insert a default notification_preferences row (all categories true) for the
    /// current user if one doesn't already exist. Existing rows are left alone.
    func seedNotificationPreferences() async {
        guard let supabase = supabase else { return }
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString.lowercased()
            let row = NotifPrefsSeedRow(
                user_id: userId,
                challenge: true,
                tasks: true,
                community: true,
                general: true
            )
            try await supabase
                .from("notification_preferences")
                .upsert(row, onConflict: "user_id", ignoreDuplicates: true)
                .execute()
        } catch {
            print("[Notif Prefs] Seed failed: \(error)")
        }
    }

    func saveDeviceToken(_ deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        guard let supabase = supabase else {
            print("[APNs] No supabase client")
            return
        }

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString.lowercased()
            print("[APNs] Saving token for user: \(userId)")

            let row = DeviceTokenRow(
                user_id: userId,
                token: token,
                platform: "ios"
            )

            try await supabase
                .from("device_tokens")
                .upsert(row, onConflict: "user_id, token")
                .execute()

            print("[APNs] Token saved successfully")
        } catch {
            print("[APNs] Failed to save token: \(error)")
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
            let category: String
            if type == "challenge", let title = challengeTitle {
                body = "\(senderName) is reminding you to finish your tasks in \(title)"
                category = "challenge"
            } else {
                body = "\(senderName) is reminding you to finish your tasks today"
                category = "tasks"
            }

            try await supabase.functions.invoke(
                "send-push",
                options: .init(body: [
                    "user_id": targetUserId,
                    "title": "Task Reminder",
                    "body": body,
                    "category": category
                ] as [String: String])
            )
        } catch {
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
            let userId = session.user.id.uuidString.lowercased()

            try await supabase
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .execute()

        } catch {
        }
    }
}

private struct DeviceTokenRow: Encodable {
    let user_id: String
    let token: String
    let platform: String
}

private struct NotifPrefsSeedRow: Encodable {
    let user_id: String
    let challenge: Bool
    let tasks: Bool
    let community: Bool
    let general: Bool
}
