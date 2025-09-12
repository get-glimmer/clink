import Foundation

enum CategoryType: String, Codable, Equatable {
    case daily
    case archived
}

struct TaskListItem: Codable, Identifiable {
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
    let privacyStatus: String?
    let type: CategoryType

    enum CodingKeys: String, CodingKey {
        case id = "categoryid"
        case userId = "userid"
        case name = "categoryname"
        case emoji = "categoryemoji" // disregard
        case privacyStatus = "privacy_status"
        case type = "categorytype"
    }
}

struct CategoryWithTasks: Identifiable {
    let id: UUID
    let category: CategoryItem
    var tasks: [TaskListItem]
}


// MARK: - CategoryModel
struct CategoryModel: Identifiable, Codable, Equatable {
    let id: UUID                         // categoryid
    var name: String                     // categoryname
    var emoji: String                    // categoryemoji
    var privacyStatus: String            // privacy_status
    //var order: Int?                      // optional: order column for sorting (future)
    var type: CategoryType? = nil        // categorytype

    enum CodingKeys: String, CodingKey {
        case id = "categoryid"
        case name = "categoryname"
        case emoji = "categoryemoji"
        case privacyStatus = "privacy_status"
        //case order
        case type = "categorytype"
    }
}

// MARK: - Category Emoji History
struct CategoryEmojiHistoryRow: Decodable {
    let emoji: String
    let effectiveDate: Date?

    enum CodingKeys: String, CodingKey {
        case emoji
        case effectiveDate = "effective_date"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        emoji = try c.decode(String.self, forKey: .emoji)
        let d = try? c.decodeIfPresent(String.self, forKey: .effectiveDate)
        effectiveDate = dateFromPostgreSQL(d)
    }
}

// MARK: - Routine (optional)
struct RoutineItem: Decodable, Identifiable {
    let id: UUID            // routineid
    let categoryId: UUID
    let title: String
    let repeatType: String  // "everyday" | "weekly" | "monthly"
    let startDate: Date
    let endDate: Date?
    let weeklyDays: [Int]?     // 0..6
    let monthlyDays: [Int]?    // 1..31

    enum CodingKeys: String, CodingKey {
        case id = "routineid"
        case categoryId = "categoryid"
        case title
        case repeatType = "repeat_type"
        case startDate = "start_date"
        case endDate   = "end_date"
        case weeklyDays = "weekly_days"
        case monthlyDays = "monthly_days"
    }
}

