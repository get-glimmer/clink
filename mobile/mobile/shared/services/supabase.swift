import Foundation
import Supabase

class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    var client: SupabaseClient?

    private init() {}

    func initialize() {
        // Try environment variables first, then fallback to Info.plist
        let url = ProcessInfo.processInfo.environment["SUPABASE_URL_KEY"] ??
                  Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL_KEY") as? String
        let anonKey = ProcessInfo.processInfo.environment["SUPABASE_PUBLIC_KEY"] ??
                      Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLIC_KEY") as? String

        guard let url = url, let anonKey = anonKey else {
            print("Supabase keys not found in environment or Info.plist")
            return
        }
        client = SupabaseClient(supabaseURL: URL(string: url)!, supabaseKey: anonKey)
    }
}
