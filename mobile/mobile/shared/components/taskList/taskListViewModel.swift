import Foundation
import Combine

@MainActor
class TaskListViewModel: ObservableObject {
    @Published var isSupabaseConnected: Bool = false
    @Published var categoriesWithTasks: [CategoryWithTasks] = [] {
        didSet { updateAllCompleted() }   // auto‑recalculate
    }
    @Published var isAllCompleted: Bool = false {
        didSet {
            if oldValue != isAllCompleted { Task { await syncShakerCompletion() } }
        }
    }

    private var cancellables = Set<AnyCancellable>()
    private let client = SupabaseClientManager.shared.client
    private let userId: String?
    @Published var taskSelectedDate: Date = Date()
    
    // is used to call its function "fetchShakers()"
    var trackerViewModel: TrackerViewModel?

    init(userId: String?, date: Date = todayDate()) {
        self.userId = userId

        // calls fetchCategoriesAndTasks() whenever taskSelectedDate changes
        $taskSelectedDate
            .sink { [weak self] _ in
                self?.fetchCategoriesAndTasks()
            }
            .store(in: &cancellables)

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
                    .order("createdat", ascending: true)
                    .execute()
                    .value

                var result: [CategoryWithTasks] = []
                for category in categories {
                    let tasks: [TaskListItem] = try await client
                        .from("task")
                        .select()
                        .eq("userid", value: userId)
                        .eq("categoryid", value: category.id.uuidString)
                        .eq("duedate", value: formattedDate(taskSelectedDate)) // changed so that "duedate" can be changed by users
                        .order("createdat", ascending: true)
                        .execute()
                        .value
                    result.append(CategoryWithTasks(id: category.id, category: category, tasks: tasks))
                }
                categoriesWithTasks = result
                
                // Also brings shaker data that will be applied to tracker
                try? await trackerViewModel?.fetchShakers()
            } catch {
                isSupabaseConnected = false
            }
        }
    }

    func toggleTaskCompletion(task: TaskListItem) {
        for (catIdx, cat) in categoriesWithTasks.enumerated() {
            if let taskIdx = cat.tasks.firstIndex(where: { $0.id == task.id }) {
                categoriesWithTasks[catIdx].tasks[taskIdx].isCompleted.toggle()
                Task {
                    await updateTaskCompletionStatus(task: categoriesWithTasks[catIdx].tasks[taskIdx])
                }
                break
            }
        }
        updateAllCompleted()
    }
    
    // All‑completed checker
    private func updateAllCompleted() {
        let concrete = categoriesWithTasks.flatMap { $0.tasks }.filter { !$0.isTemporary }
        isAllCompleted = !concrete.isEmpty && concrete.allSatisfy { $0.isCompleted }
    }

    // Supabase: shaker table sync
    private func syncShakerCompletion() async {
        guard let client = client, let userId = userId else { return }

        struct ShakerRow: Codable {
            let userid: String
            let date: String
            let iscompleted: Bool // whether to seal the jar or not
        }

        let row = ShakerRow(
            userid: userId,
            date: formattedDate(taskSelectedDate),
            iscompleted: isAllCompleted
        )

        do {
            try await client
                .from("shaker")
                .upsert(row)
                .execute()
        } catch {
            print("[ShakerSync] upsert failed: \(error)")
        }
    }


    func createTemporaryTask(categoryId: UUID) {
        // Create a temporary task locally without server communication
        let temporaryTask = TaskListItem(
            id: UUID(),
            title: "",
            isCompleted: false,
            dueDate: taskSelectedDate,
            isTemporary: true
        )
        
        // Find the category and add the temporary task
        for (catIdx, cat) in categoriesWithTasks.enumerated() {
            if cat.category.id == categoryId {
                categoriesWithTasks[catIdx].tasks.append(temporaryTask)
                break
            }
        }
        updateAllCompleted()
    }
    
    func saveTemporaryTask(task: TaskListItem, newTitle: String) async {
        guard let client = self.client else { return }
        guard let userId = self.userId else { return }
        guard task.isTemporary else { return }
        
        // Find the category this task belongs to
        var categoryId: UUID?
        var categoryEmoji: String? = nil
        for cat in categoriesWithTasks {
            if cat.tasks.contains(where: { $0.id == task.id }) {
                categoryId = cat.category.id
                categoryEmoji = cat.category.emoji
                break
            }
        }
        
        guard let categoryId = categoryId else { return }
        
        do {
            // Save to server using the target date
            try await client.from("task").insert([
                "categoryid": categoryId.uuidString,
                "userid": userId,
                "duedate": dateToPostgreSQLString(taskSelectedDate),
                "tasktitle": newTitle
            ]).execute()
            
            // Remove temporary task and refresh from server
            removeTemporaryTask(task: task)
            fetchCategoriesAndTasks()
        } catch {
            print("Failed to save task: \(error)")
            // Keep the temporary task if save failed
        }
    }
    
    func removeTemporaryTask(task: TaskListItem) {
        for (catIdx, cat) in categoriesWithTasks.enumerated() {
            if let taskIdx = cat.tasks.firstIndex(where: { $0.id == task.id }) {
                categoriesWithTasks[catIdx].tasks.remove(at: taskIdx)
                break
            }
        }
        updateAllCompleted()
    }

    func updateTaskCompletionStatus(task: TaskListItem) async {
        guard let client = self.client else { return }
        guard let userId = self.userId else { return }
        do {
            try await client
                .from("task")
                .update(["iscompleted": task.isCompleted])
                .eq("taskid", value: task.id)
                .eq("userid", value: userId)
                .execute()
            
            // Also brings shaker data that will be applied to tracker
            try? await trackerViewModel?.fetchShakers()
        } catch {
            // Handle error if needed
        }
    }

    func deleteTask(task: TaskListItem) async {
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
            
            // Also brings shaker data that will be applied to tracker
            try? await trackerViewModel?.fetchShakers()
        } catch {
            // Handle error if needed
        }
    }
}
