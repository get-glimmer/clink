import Foundation
import Combine

@MainActor
class TaskViewModel: ObservableObject {
    @Published var isSupabaseConnected: Bool = false
    @Published var categoriesWithTasks: [CategoryWithTasks] = []

    private var cancellables = Set<AnyCancellable>()
    private let client = SupabaseClientManager.shared.client
    private let userId: String?

    init(userId: String?) {
        self.userId = userId
        fetchCategoriesAndTasks()
    }

    func fetchCategoriesAndTasks() {
        guard let client = self.client else {
            self.isSupabaseConnected = false
            return
        }
        guard let userId = self.userId else {
            self.isSupabaseConnected = false
            return
        }
        self.isSupabaseConnected = true

        Task {
            do {
                let categories: [CategoryItem] = try await client
                    .from("category")
                    .select()
                    .eq("userid", value: userId)
                    .execute()
                    .value

                var result: [CategoryWithTasks] = []
                for category in categories {
                    let tasks: [TaskItem] = try await client
                        .from("task")
                        .select()
                        .eq("userid", value: userId)
                        .eq("categoryid", value: category.id.uuidString)
                        .execute()
                        .value
                    result.append(CategoryWithTasks(id: category.id, category: category, tasks: tasks))
                }
                categoriesWithTasks = result
            } catch {
                isSupabaseConnected = false
            }
        }
    }

    func toggleTaskCompletion(task: TaskItem) {
        for (catIdx, cat) in categoriesWithTasks.enumerated() {
            if let taskIdx = cat.tasks.firstIndex(where: { $0.id == task.id }) {
                categoriesWithTasks[catIdx].tasks[taskIdx].isCompleted.toggle()
                Task {
                    await updateTaskCompletionStatus(task: categoriesWithTasks[catIdx].tasks[taskIdx])
                }
                break
            }
        }
    }

    func updateTaskCompletionStatus(task: TaskItem) async {
        guard let client = self.client else { return }
        guard let userId = self.userId else { return }
        do {
            try await client
                .from("task")
                .update(["iscompleted": task.isCompleted])
                .eq("taskid", value: task.id)
                .eq("userid", value: userId)
                .execute()
        } catch {
            // Handle error if needed
        }
    }

    func deleteTask(task: TaskItem) async {
        guard let client = self.client else { return }
        guard let userId = self.userId else { return }
        do {
            try await client
                .from("task")
                .delete()
                .eq("taskid", value: task.id)
                .eq("userid", value: userId)
                .execute()
            // Remove from local list after successful deletion
            for (catIdx, cat) in categoriesWithTasks.enumerated() {
                if let taskIdx = cat.tasks.firstIndex(where: { $0.id == task.id }) {
                    categoriesWithTasks[catIdx].tasks.remove(at: taskIdx)
                    break
                }
            }
        } catch {
            // Handle error if needed
        }
    }
}
