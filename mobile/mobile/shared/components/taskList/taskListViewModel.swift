import Foundation
import Combine

@MainActor
class TaskListViewModel: ObservableObject {
    // MARK: - Variables
    @Published var isSupabaseConnected: Bool = false
    @Published var categoriesWithTasks: [CategoryWithTasks] = [] {
        didSet { updateAllCompleted() }   // auto‑recalculate
    }
    @Published var isAllCompleted: Bool = false {
        didSet {
            if oldValue != isAllCompleted && !suppressSync{ Task { await syncShakerCompletion() } }
        }
    }
    // Lid color storage
    @Published var lidColorStart: String? = nil
    @Published var lidColorEnd:   String? = nil
    
    // Prevent automatic DB‐sync on initial load
    private var suppressSync: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let client = SupabaseClientManager.shared.client
    private let userId: String?
    @Published var taskSelectedDate: Date = Date()
    
    // is used to call its function "fetchShakers()"
    var trackerViewModel: TrackerViewModel?

    // MARK: - init
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
    
    // MARK: - fetching
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

                // ──────── Lid Gradient Colors load ────────
                suppressSync = true
                do {
                    struct DBRow: Decodable {
                        let iscompleted: Bool
                        let lid_color_start: String?
                        let lid_color_end:   String?
                    }
                    if let row: DBRow = try await client
                        .from("shaker")
                        .select("iscompleted,lid_color_start,lid_color_end")
                        .eq("userid", value: userId)
                        .eq("date", value: formattedDate(taskSelectedDate))
                        .execute()
                        .value
                    {
                        // UI reflected state
                        isAllCompleted   = row.iscompleted
                        lidColorStart = row.lid_color_start
                        lidColorEnd   = row.lid_color_end
                    }
                } catch {
                    // ignore load failures
                }
                suppressSync = false


                // Also brings shaker data that will be applied to tracker
                try? await trackerViewModel?.fetchShakers()

            } catch {
                isSupabaseConnected = false
            }
        }
    }

    // MARK: - task toggle
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
        categoriesWithTasks = categoriesWithTasks
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

            updateAllCompleted()

            // Also brings shaker data that will be applied to tracker
            try? await trackerViewModel?.fetchShakers()

        } catch {
            // Handle error if needed
        }
    }
    
    // MARK: - shaker lid sealing
    // All‑completed checker
    private func updateAllCompleted() {
        let allTasks = categoriesWithTasks.flatMap { $0.tasks }
        isAllCompleted = !allTasks.isEmpty && allTasks.allSatisfy { $0.isCompleted }
    }

    // Supabase: shaker table sync
    private func syncShakerCompletion() async {
        guard let client = client, let userId = userId else { return }

        struct ShakerRow: Codable {
            let userid: String
            let date: String
            let iscompleted: Bool // whether to seal the jar or not
            let lid_color_start: String? // seal 시점에만 저장
            let lid_color_end: String?
        }

        let row = ShakerRow(
            userid: userId,
            date: formattedDate(taskSelectedDate),
            iscompleted: isAllCompleted,
            // sealing 상태라면 색상, 아니면 nil 전달
            lid_color_start: isAllCompleted ? lidColorStart : nil,
            lid_color_end:   isAllCompleted ? lidColorEnd   : nil
        )

        do {
            try await client
                .from("shaker")
                .upsert(row, onConflict: "userid,date")
                .execute()
        } catch {
            print("[ShakerSync] upsert failed: \(error)")
        }
    }
    
    // Store gradient colors (for the first sealing) in DB
    func updateShakerLidColors(start: String, end: String) async {
        guard let client, let userId else { return }
        do {
            try await client
                .from("shaker")
                .update(["lid_color_start": start, "lid_color_end": end])
                .eq("userid", value: userId)
                .eq("date",   value: formattedDate(taskSelectedDate))
                .execute()
            await MainActor.run {
                lidColorStart = start
                lidColorEnd   = end
            }
        } catch { print("[ShakerSync] colour update failed:", error) }
    }

    // MARK: - create task
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
            // removeTemporaryTask(task: task)
            fetchCategoriesAndTasks()
            isAllCompleted = false
            
        } catch {
            print("Failed to save task: \(error)")
            // Keep the temporary task if save failed
        }
        
    }
    
    // MARK: - delete task
    func removeTemporaryTask(task: TaskListItem) {
        for (catIdx, cat) in categoriesWithTasks.enumerated() {
            if let taskIdx = cat.tasks.firstIndex(where: { $0.id == task.id }) {
                categoriesWithTasks[catIdx].tasks.remove(at: taskIdx)
                break
            }
        }
        updateAllCompleted()
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

            updateAllCompleted()

            // Also brings shaker data that will be applied to tracker
            try? await trackerViewModel?.fetchShakers()

        } catch {
            // Handle error if needed
        }
    }
    
    // MARK: - create category
    func addCategory(name: String, emoji: String, privacyStatus: String) async throws {
        guard let client = self.client, let userId = self.userId else { return }

        // Match your Supabase schema column names exactly.
        struct NewCategory: Encodable {
            let userid: String
            let categoryname: String
            let categoryemoji: String
            let privacy_status: String
        }

        let payload = NewCategory(
            userid: userId,
            categoryname: name,
            categoryemoji: emoji,
            privacy_status: privacyStatus
        )

        do {
            try await client
                .from("category")
                .insert(payload)
                .execute()

            await MainActor.run {
                self.fetchCategoriesAndTasks()
            }
        } catch {
            print("[Category] insert failed:", error)
            throw error
        }
    }
    
    // MARK: - update category
    func updateCategory(categoryId: UUID, name: String, emoji: String, privacyStatus: String) async {
        guard let client = self.client, let userId = self.userId else { return }
        do {
            // 1) Update on DB
            try await client
                .from("category")
                .update([
                    "categoryname": name,
                    "categoryemoji": emoji,
                    "privacy_status": privacyStatus
                ])
                .eq("categoryid", value: categoryId)
                .eq("userid", value: userId)
                .execute()

            // 2) Reflect locally (rebuild the item since `category` is let)
            await MainActor.run {
                if let idx = categoriesWithTasks.firstIndex(where: { $0.id == categoryId }) {
                    let old = categoriesWithTasks[idx]
                    let updatedCategory = CategoryItem(
                        id: old.category.id,
                        userId: old.category.userId,
                        name: name,
                        emoji: emoji,
                        privacyStatus: privacyStatus
                    )
                    categoriesWithTasks[idx] = CategoryWithTasks(
                        id: old.id,
                        category: updatedCategory,
                        tasks: old.tasks
                    )
                }
            }
        } catch {
            print("[Category] update failed:", error)
        }
    }
    
    // MARK: - delete category
    func deleteCategory(categoryId: UUID) async {
        guard let client = self.client, let userId = self.userId else { return }
        do {
            try await client
                .from("category")
                .delete()
                .eq("categoryid", value: categoryId)
                .eq("userid", value: userId)
                .execute()

            await MainActor.run {
                categoriesWithTasks.removeAll { $0.category.id == categoryId }
            }
        } catch {
            print("[Category] delete failed:", error)
        }
    }

    // MARK: - reorder categories (local only for now)
    func moveCategories(from source: IndexSet, to destination: Int) {
        categoriesWithTasks.move(fromOffsets: source, toOffset: destination)
    }


}
