import Foundation
import Supabase

class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    var client: SupabaseClient?

    private init() {}

    func initialize() {
        // Prefer Info.plist values via AppConfig; fall back to scheme env vars for local dev
        let url = AppConfig.supabaseUrl.isEmpty
            ? (ProcessInfo.processInfo.environment["SUPABASE_URL_KEY"] ?? "")
            : AppConfig.supabaseUrl
        let anonKey = AppConfig.supabaseAnonKey.isEmpty
            ? (ProcessInfo.processInfo.environment["SUPABASE_PUBLIC_KEY"] ?? "")
            : AppConfig.supabaseAnonKey

        guard !url.isEmpty, !anonKey.isEmpty, let supabaseURL = URL(string: url) else {
            print("Supabase keys not found or invalid. Ensure Build Settings have SUPABASE_URL_KEY and SUPABASE_PUBLIC_KEY.")
            return
        }
        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: anonKey)
    }
}
