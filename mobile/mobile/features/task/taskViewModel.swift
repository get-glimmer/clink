import Foundation
import Combine

@MainActor
class TaskViewModel: ObservableObject {
    @Published var isSupabaseConnected: Bool = false
    @Published var statusMessage: String = "Connecting to Supabase..."
    @Published var tasks: [TaskItem] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        fetchTasks()
    }

    func fetchTasks() {
        guard let client = SupabaseClientManager.shared.client else {
            self.statusMessage = "Supabase client not initialized."
            self.isSupabaseConnected = false
            return
        }
        
        self.isSupabaseConnected = true // Tentatively set to true
        self.statusMessage = "Fetching tasks..."

        Task {
            do {
                let response: [TaskItem] = try await client
                    .from("task")
                    .select()
                    .execute()
                    .value
                
                tasks = response
                statusMessage = "Successfully fetched \(response.count) tasks."
            } catch {
                statusMessage = "Failed to fetch tasks: \(error.localizedDescription)"
                isSupabaseConnected = false
            }
        }
    }
}
