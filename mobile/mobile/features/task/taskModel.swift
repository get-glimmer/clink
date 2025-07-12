import Foundation

struct TaskItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    var isCompleted: Bool
    let dueDate: Date?

    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case title = "tasktitle"
        case content = "taskcontent"
        case isCompleted = "iscompleted"
        case dueDate = "duedate"
    }
}

struct CategoryItem: Codable, Identifiable {
    let id: UUID
    let userId: String
    let name: String
    let emoji: String

    enum CodingKeys: String, CodingKey {
        case id = "categoryid"
        case userId = "userid"
        case name = "categoryname"
        case emoji = "categoryemoji"
    }
}

struct CategoryWithTasks: Identifiable {
    let id: UUID
    let category: CategoryItem
    var tasks: [TaskItem]
}
