import Foundation
import Combine

@MainActor
class TaskViewModel: ObservableObject {
    @Published var isSupabaseConnected: Bool = false
    @Published var tasks: [TaskItem] = []

    private var cancellables = Set<AnyCancellable>()
    private let client = SupabaseClientManager.shared.client

    init() {
        fetchTasks()
    }

    func fetchTasks() {
        guard let client = self.client else {
            self.isSupabaseConnected = false
            return
        }
        
        self.isSupabaseConnected = true // Tentatively set to true

        Task {
            do {
                let response: [TaskItem] = try await client
                    .from("task")
                    .select()
                    .execute()
                    .value
                
                tasks = response
            } catch {
                isSupabaseConnected = false
            }
        }
    }

    func toggleTaskCompletion(task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        Task {
            await updateTaskCompletionStatus(task: tasks[index])
        }
    }

    func updateTaskCompletionStatus(task: TaskItem) async {
        guard let client = self.client else { return }
        do {
            try await client
                .from("task")
                .update(["iscompleted": task.isCompleted])
                .eq("taskid", value: task.id)
                .execute()
        } catch {
            // Handle error if needed
        }
    }

    func deleteTask(task: TaskItem) async {
        guard let client = self.client else { return }
        do {
            try await client
                .from("task")
                .delete()
                .eq("taskid", value: task.id)
                .execute()
            // Remove from local list after successful deletion
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks.remove(at: index)
            }
        } catch {
            // Handle error if needed
        }
    }
}
