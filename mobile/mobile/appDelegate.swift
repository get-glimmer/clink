import UIKit
// importing Supabase
import Supabase

// initialize supabase client
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://msgokklebwjsqcaizynq.supabase.co")!,
    
    // it's okay to expose this public key
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zZ29ra2xlYndqc3FjYWl6eW5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk4NjU5MjEsImV4cCI6MjA2NTQ0MTkyMX0.hoFbrGyd8ZQIMf6rB2-mRn3xlHWBo4UvxnIkBSOxpf4"
)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Initialize Supabase client
        // SupabaseClientManager.shared.initialize()
        return true
    }
}
