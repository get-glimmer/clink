import Foundation
import Supabase

class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    var client: SupabaseClient?

    private init() {}

    func initialize() {
        // Replace with your method of loading keys, e.g., from Info.plist
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL_KEY") as? String,
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLIC_KEY") as? String else {
            print("Supabase keys not found in Info.plist")
            return
        }
        client = SupabaseClient(supabaseURL: URL(string: url)!, supabaseKey: anonKey)
    }
}
