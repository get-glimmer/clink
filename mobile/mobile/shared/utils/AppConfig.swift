import Foundation

enum AppConfig {
    static var supabaseUrl: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "supabase_url_key") as? String,
              !value.isEmpty else {
            return ""
        }
        return value
    }
    
    static var supabaseAnonKey: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "supabase_public_key") as? String,
              !value.isEmpty else {
            return ""
        }
        return value
    }
}