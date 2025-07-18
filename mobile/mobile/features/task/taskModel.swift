import Foundation

struct TaskItem: Codable, Identifiable {
    let id: UUID
    let title: String
    var isCompleted: Bool
    let dueDate: Date?
    var isTemporary: Bool = false

    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case title = "tasktitle"
        case isCompleted = "iscompleted"
        case dueDate = "duedate"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        
        // Use utility function to convert PostgreSQL date
        let dueDateString = try? container.decodeIfPresent(String.self, forKey: .dueDate)
        dueDate = dateFromPostgreSQL(dueDateString)
        isTemporary = false
    }
    
    // Convenience initializer for creating tasks manually
    init(id: UUID, title: String, isCompleted: Bool, dueDate: Date?, isTemporary: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.isTemporary = isTemporary
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
