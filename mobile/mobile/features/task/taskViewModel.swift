import Foundation
import Combine

class TaskViewModel: ObservableObject {
    @Published var isSupabaseConnected: Bool = false
    @Published var statusMessage: String = ""

    init() {
        checkSupabaseConnection()
    }

    func checkSupabaseConnection() {
        SupabaseClientManager.shared.initialize()
        if let client = SupabaseClientManager.shared.client {
            isSupabaseConnected = true
            statusMessage = "Supabase is connected."
        } else {
            isSupabaseConnected = false
            statusMessage = "Supabase is NOT connected."
        }
    }
}
