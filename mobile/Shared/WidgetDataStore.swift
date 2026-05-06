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
    let emojiPositions: [[Double]]? // [[normalizedX, normalizedY], ...] from SpriteKit scene
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
           
            return
        }
        guard let data = try? JSONEncoder().encode(categories) else {
          
            return
        }
        defaults?.set(data, forKey: tasksKey)
        defaults?.synchronize()
       
    }

    func loadTasks() -> [WidgetCategoryTasks] {
        if defaults == nil {
            
            return []
        }
        guard let data = defaults?.data(forKey: tasksKey) else {
           
            return []
        }
        guard let categories = try? JSONDecoder().decode([WidgetCategoryTasks].self, from: data) else {

            return []
        }
       
        return categories
    }

    // MARK: Shaker

    func saveShaker(_ data: WidgetShakerData) {
        if defaults == nil {
           
            return
        }
        guard let encoded = try? JSONEncoder().encode(data) else {
           
            return
        }
        defaults?.set(encoded, forKey: shakerKey)
        defaults?.synchronize()
    }

    func loadShaker() -> WidgetShakerData? {
        if defaults == nil {
           
            return nil
        }
        guard let data = defaults?.data(forKey: shakerKey) else {
            return nil
        }
        guard let shaker = try? JSONDecoder().decode(WidgetShakerData.self, from: data) else {
            return nil
        }
        return shaker
    }
}
