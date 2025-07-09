import Foundation

struct TaskItem: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let isCompleted: Bool
    let dueDate: Date?

    enum CodingKeys: String, CodingKey {
        case id = "taskid"
        case title = "tasktitle"
        case content = "taskcontent"
        case isCompleted = "iscompleted"
        case dueDate = "duedate"
    }
}
