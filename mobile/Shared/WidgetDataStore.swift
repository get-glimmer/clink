import Foundation

let appGroupID = "group.kristie123.mobile"

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let categoryName: String
    let categoryEmoji: String
}

struct WidgetCategoryTasks: Codable, Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let tasks: [WidgetTask]
}

final class WidgetDataStore {
    static let shared = WidgetDataStore()
    private let defaults = UserDefaults(suiteName: appGroupID)

    private let tasksKey = "widget_tasks"

    func saveTasks(_ categories: [WidgetCategoryTasks]) {
        if defaults == nil {
            print("[WidgetDataStore] ERROR: UserDefaults is nil — App Group '\(appGroupID)' not configured")
            return
        }
        guard let data = try? JSONEncoder().encode(categories) else {
            print("[WidgetDataStore] ERROR: failed to encode tasks")
            return
        }
        defaults?.set(data, forKey: tasksKey)
        defaults?.synchronize()
        print("[WidgetDataStore] saved \(data.count) bytes")
    }

    func loadTasks() -> [WidgetCategoryTasks] {
        if defaults == nil {
            print("[WidgetDataStore] ERROR: UserDefaults is nil — App Group '\(appGroupID)' not configured")
            return []
        }
        guard let data = defaults?.data(forKey: tasksKey) else {
            print("[WidgetDataStore] no data found for key '\(tasksKey)'")
            return []
        }
        guard let categories = try? JSONDecoder().decode([WidgetCategoryTasks].self, from: data) else {
            print("[WidgetDataStore] ERROR: failed to decode tasks")
            return []
        }
        print("[WidgetDataStore] loaded \(categories.count) categories")
        return categories
    }
}
