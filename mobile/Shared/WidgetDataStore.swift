import Foundation

let appGroupID = "group.kristie123.mobile"

// MARK: - Task List Widget Data

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

// MARK: - Shaker Widget Data

struct WidgetShakerData: Codable {
    let emojis: [String]           // completed task emojis in the jar
    let isAllCompleted: Bool
    let lidColorStart: String?     // hex color
    let lidColorEnd: String?       // hex color
}

// MARK: - Data Store

final class WidgetDataStore {
    static let shared = WidgetDataStore()
    private let defaults = UserDefaults(suiteName: appGroupID)

    private let tasksKey = "widget_tasks"
    private let shakerKey = "widget_shaker"

    // MARK: Tasks

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

    // MARK: Shaker

    func saveShaker(_ data: WidgetShakerData) {
        if defaults == nil {
            print("[WidgetDataStore] ERROR: UserDefaults is nil for shaker save")
            return
        }
        guard let encoded = try? JSONEncoder().encode(data) else {
            print("[WidgetDataStore] ERROR: failed to encode shaker")
            return
        }
        defaults?.set(encoded, forKey: shakerKey)
        defaults?.synchronize()
        print("[WidgetDataStore] saved shaker: \(data.emojis.count) emojis \(data.emojis), allDone=\(data.isAllCompleted)")
    }

    func loadShaker() -> WidgetShakerData? {
        if defaults == nil {
            print("[WidgetDataStore] ERROR: UserDefaults is nil for shaker load")
            return nil
        }
        guard let data = defaults?.data(forKey: shakerKey) else {
            print("[WidgetDataStore] no shaker data found")
            return nil
        }
        guard let shaker = try? JSONDecoder().decode(WidgetShakerData.self, from: data) else {
            print("[WidgetDataStore] ERROR: failed to decode shaker")
            return nil
        }
        print("[WidgetDataStore] loaded shaker: \(shaker.emojis.count) emojis \(shaker.emojis)")
        return shaker
    }
}
